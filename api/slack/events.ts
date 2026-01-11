import crypto from "crypto";
import { WebClient } from "@slack/web-api";
import { createClient } from "@supabase/supabase-js";
import type { VercelRequest, VercelResponse } from "@vercel/node";
import { buffer } from "micro";

// Disable Vercel's automatic body parsing
export const config = {
  api: {
    bodyParser: false,
  },
};

// Initialize clients lazily
let slackClient: WebClient | null = null;
let supabaseClient: ReturnType<typeof createClient> | null = null;

function getSlackClient() {
  if (!slackClient) {
    slackClient = new WebClient(process.env.SLACK_BOT_TOKEN);
  }
  return slackClient;
}

function getSupabase() {
  if (!supabaseClient) {
    supabaseClient = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_KEY!
    );
  }
  return supabaseClient;
}

// Mood configuration
const MOODS = [
  { score: 1, emoji: "😭", label: "Awful", action_id: "mood_1" },
  { score: 2, emoji: "☹️", label: "Not great", action_id: "mood_2" },
  { score: 3, emoji: "😐", label: "Okay", action_id: "mood_3" },
  { score: 4, emoji: "🙂", label: "Good", action_id: "mood_4" },
  { score: 5, emoji: "😄", label: "Great", action_id: "mood_5" },
] as const;

// Get time-appropriate greeting (UK timezone)
function getGreeting(): string {
  const ukTime = new Date().toLocaleString("en-GB", { timeZone: "Europe/London", hour: "numeric", hour12: false });
  const hour = parseInt(ukTime, 10);
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

// Build mood message blocks
function buildMoodMessage(sourceChannelId?: string, responseUrl?: string) {
  return [
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: `👋 *${getGreeting()}!* How are you feeling today?`,
      },
    },
    {
      type: "actions",
      elements: MOODS.map((mood) => ({
        type: "button",
        text: { type: "plain_text", text: mood.emoji, emoji: true },
        value: JSON.stringify({ score: mood.score, emoji: mood.emoji, source_channel_id: sourceChannelId, response_url: responseUrl }),
        action_id: mood.action_id,
      })),
    },
  ];
}

// Verify Slack request signature
function verifySlackSignature(req: VercelRequest, body: string): boolean {
  const timestamp = req.headers["x-slack-request-timestamp"] as string;
  const signature = req.headers["x-slack-signature"] as string;
  const signingSecret = process.env.SLACK_SIGNING_SECRET!;

  if (!timestamp || !signature) return false;

  // Check timestamp is within 5 minutes
  const time = Math.floor(Date.now() / 1000);
  if (Math.abs(time - parseInt(timestamp)) > 300) return false;

  const sigBasestring = `v0:${timestamp}:${body}`;
  const mySignature = `v0=${crypto.createHmac("sha256", signingSecret).update(sigBasestring).digest("hex")}`;

  return crypto.timingSafeEqual(Buffer.from(mySignature), Buffer.from(signature));
}

// Handle slash commands
async function handleSlashCommand(payload: any, res: VercelResponse) {
  const { command, channel_id, response_url, user_id } = payload;

  if (command === "/mood") {
    return res.status(200).json({
      response_type: "ephemeral",
      blocks: buildMoodMessage(channel_id, response_url),
    });
  }

  if (command === "/my-moods") {
    const { data, error } = await getSupabase()
      .from("mood_entries")
      .select("mood_emoji, mood_score, additional_context, recorded_at")
      .eq("slack_user_id", user_id)
      .order("recorded_at", { ascending: false })
      .limit(7);

    if (error || !data?.length) {
      return res.status(200).json({
        response_type: "ephemeral",
        text: "No mood entries found yet. Use `/mood` to log your first one!",
      });
    }

    const moodList = data
      .map((entry) => {
        const date = new Date(entry.recorded_at).toLocaleDateString("en-GB", {
          weekday: "short", day: "numeric", month: "short",
        });
        const context = entry.additional_context ? ` - _"${entry.additional_context}"_` : "";
        return `• ${date}: ${entry.mood_emoji}${context}`;
      })
      .join("\n");

    const avgMood = data.reduce((sum, e) => sum + e.mood_score, 0) / data.length;

    return res.status(200).json({
      response_type: "ephemeral",
      blocks: [{
        type: "section",
        text: {
          type: "mrkdwn",
          text: `*Your recent moods* (last ${data.length} entries)\nAverage: ${avgMood.toFixed(1)}/5\n\n${moodList}`,
        },
      }],
    });
  }

  return res.status(200).json({ text: "Unknown command" });
}

// Handle interactive components (button clicks, modal submissions)
async function handleInteraction(payload: any, res: VercelResponse) {
  const client = getSlackClient();
  const supabase = getSupabase();

  // Handle button clicks
  if (payload.type === "block_actions") {
    const action = payload.actions[0];
    if (action.action_id.startsWith("mood_")) {
      const moodData = JSON.parse(action.value);
      const channelId = moodData.source_channel_id || payload.channel?.id;

      await client.views.open({
        trigger_id: payload.trigger_id,
        view: {
          type: "modal",
          callback_id: "mood_context_modal",
          private_metadata: JSON.stringify({
            score: moodData.score,
            emoji: moodData.emoji,
            channel_id: channelId,
            message_ts: payload.message?.ts,
            response_url: moodData.response_url,
          }),
          title: { type: "plain_text", text: "Mood Check-in" },
          submit: { type: "plain_text", text: "Submit" },
          close: { type: "plain_text", text: "Skip" },
          blocks: [
            {
              type: "section",
              text: { type: "mrkdwn", text: `You selected *${moodData.emoji}* - thanks for sharing!` },
            },
            {
              type: "input",
              block_id: "context_block",
              optional: true,
              element: {
                type: "plain_text_input",
                action_id: "context_input",
                multiline: true,
                placeholder: { type: "plain_text", text: "Anything you'd like to add? (optional)" },
              },
              label: { type: "plain_text", text: "Additional context" },
            },
          ],
        },
      });
    }
    return res.status(200).send("");
  }

  // Handle modal submission
  if (payload.type === "view_submission" && payload.view.callback_id === "mood_context_modal") {
    const metadata = JSON.parse(payload.view.private_metadata);
    const contextValue = payload.view.state.values.context_block?.context_input?.value || null;
    const userId = payload.user.id;

    // Save to Supabase in background
    saveMoodEntry(client, supabase, userId, metadata, contextValue, payload.team?.id);

    return res.status(200).send("");
  }

  // Handle modal close/skip
  if (payload.type === "view_closed" && payload.view.callback_id === "mood_context_modal") {
    const metadata = JSON.parse(payload.view.private_metadata);
    const userId = payload.user.id;

    // Save to Supabase in background (without context)
    saveMoodEntry(client, supabase, userId, metadata, null, payload.team?.id);

    return res.status(200).send("");
  }

  return res.status(200).send("");
}

// Save mood entry and send confirmations (runs after response)
async function saveMoodEntry(
  client: WebClient,
  supabase: ReturnType<typeof createClient>,
  userId: string,
  metadata: any,
  contextValue: string | null,
  teamId: string | undefined
) {
  try {
    const userInfo = await client.users.info({ user: userId });
    const displayName = userInfo.user?.profile?.display_name || userInfo.user?.profile?.real_name || "Someone";

    // Save to Supabase
    await supabase.from("mood_entries").insert({
      slack_user_id: userId,
      slack_username: userInfo.user?.name,
      slack_display_name: displayName,
      mood_score: metadata.score,
      mood_emoji: metadata.emoji,
      additional_context: contextValue,
      slack_team_id: teamId,
    });

    let messageUpdated = false;

    // Try to update original message
    if (metadata.channel_id && metadata.message_ts) {
      try {
        await client.chat.update({
          channel: metadata.channel_id,
          ts: metadata.message_ts,
          blocks: [{
            type: "section",
            text: { type: "mrkdwn", text: `✅ *${displayName}* is feeling ${metadata.emoji} today.` },
          }],
          text: `Mood recorded: ${displayName} - ${metadata.emoji}`,
        });
        messageUpdated = true;
      } catch (e) {
        console.log("Could not update original message");
      }
    }

    // Send confirmation
    if (!messageUpdated) {
      const confirmationText = `✅ *${displayName}*, your mood has been logged: ${metadata.emoji}${contextValue ? ` - "${contextValue}"` : ""}`;

      if (metadata.response_url) {
        try {
          await fetch(metadata.response_url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ text: confirmationText, response_type: "ephemeral" }),
          });
        } catch (e) {
          console.log("Could not send response_url confirmation");
        }
      } else if (metadata.channel_id) {
        const isDM = metadata.channel_id.startsWith("D");
        try {
          if (isDM) {
            await client.chat.postMessage({ channel: metadata.channel_id, text: confirmationText });
          } else {
            await client.chat.postEphemeral({ channel: metadata.channel_id, user: userId, text: confirmationText });
          }
        } catch (e) {
          console.log("Could not send confirmation");
        }
      }
    }

    // Send DM confirmation
    await client.chat.postMessage({
      channel: userId,
      text: `✅ *${displayName}*, your mood has been logged: ${metadata.emoji}${contextValue ? ` - "${contextValue}"` : ""}`,
    });

    // Post to mood channel if configured
    const moodChannelId = process.env.MOOD_CHANNEL_ID;
    if (moodChannelId) {
      try {
        await client.chat.postMessage({
          channel: moodChannelId,
          text: `*${displayName}* is feeling ${metadata.emoji} today${contextValue ? ` - "${contextValue}"` : ""}`,
        });
      } catch (e) {
        console.log("Could not post to mood channel");
      }
    }
  } catch (error) {
    console.error("Error saving mood entry:", error);
  }
}

// Main handler
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Read raw body for signature verification
  const rawBody = (await buffer(req)).toString("utf-8");
  const contentType = req.headers["content-type"] || "";

  // Parse body based on content type
  let body: any;
  if (contentType.includes("application/json")) {
    body = JSON.parse(rawBody);
  } else if (contentType.includes("application/x-www-form-urlencoded")) {
    body = Object.fromEntries(new URLSearchParams(rawBody));
  } else {
    body = rawBody;
  }

  // Handle URL verification (doesn't need signature check)
  if (body?.type === "url_verification") {
    return res.status(200).json({ challenge: body.challenge });
  }

  // Verify signature using the raw body
  if (!verifySlackSignature(req, rawBody)) {
    console.log("Signature verification failed");
    return res.status(401).json({ error: "Invalid signature" });
  }

  // Handle slash commands (form-urlencoded)
  if (body.command) {
    return handleSlashCommand(body, res);
  }

  // Handle interactions (form-urlencoded with payload)
  if (body.payload) {
    const payload = JSON.parse(body.payload);
    return handleInteraction(payload, res);
  }

  // Handle events API
  if (body.type === "event_callback") {
    // Handle events if needed
    return res.status(200).send("");
  }

  return res.status(200).send("");
}
