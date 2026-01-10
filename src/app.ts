import { App, BlockAction, ViewSubmitAction } from "@slack/bolt";
import { KnownBlock } from "@slack/types";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import "dotenv/config";

// Validate required environment variables
const requiredEnvVars = [
  "SLACK_BOT_TOKEN",
  "SLACK_SIGNING_SECRET",
  "SLACK_APP_TOKEN",
  "SUPABASE_URL",
  "SUPABASE_SERVICE_KEY",
];

const missingVars = requiredEnvVars.filter((v) => !process.env[v]);
if (missingVars.length > 0) {
  console.error("Missing required environment variables:", missingVars.join(", "));
  console.error("Available env vars:", Object.keys(process.env).filter(k => k.includes("SLACK") || k.includes("SUPABASE")).join(", ") || "(none matching)");
  process.exit(1);
}

// Mood configuration
const MOODS = [
  { score: 1, emoji: "😭", label: "Awful", action_id: "mood_1" },
  { score: 2, emoji: "☹️", label: "Not great", action_id: "mood_2" },
  { score: 3, emoji: "😐", label: "Okay", action_id: "mood_3" },
  { score: 4, emoji: "🙂", label: "Good", action_id: "mood_4" },
  { score: 5, emoji: "😄", label: "Great", action_id: "mood_5" },
] as const;

// Initialise Supabase client
const supabase: SupabaseClient = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

// Initialise Slack app
const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  signingSecret: process.env.SLACK_SIGNING_SECRET,
  socketMode: true,
  appToken: process.env.SLACK_APP_TOKEN,
});

// Build the mood check-in message blocks
function buildMoodMessage(): KnownBlock[] {
  return [
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: "👋 *Good morning!* How are you feeling today?",
      },
    },
    {
      type: "actions",
      elements: MOODS.map((mood) => ({
        type: "button" as const,
        text: {
          type: "plain_text" as const,
          text: mood.emoji,
          emoji: true,
        },
        value: JSON.stringify({ score: mood.score, emoji: mood.emoji }),
        action_id: mood.action_id,
      })),
    },
  ];
}

// Handle mood button clicks
MOODS.forEach((mood) => {
  app.action<BlockAction>(mood.action_id, async ({ ack, body, client }) => {
    await ack();

    const userId = body.user.id;
    const moodData = JSON.parse(
      (body as any).actions[0].value
    ) as { score: number; emoji: string };

    // Open modal for additional context
    await client.views.open({
      trigger_id: (body as any).trigger_id,
      view: {
        type: "modal",
        callback_id: "mood_context_modal",
        private_metadata: JSON.stringify({
          ...moodData,
          channel_id: (body as any).channel?.id,
          message_ts: (body as any).message?.ts,
        }),
        title: {
          type: "plain_text",
          text: "Mood Check-in",
        },
        submit: {
          type: "plain_text",
          text: "Submit",
        },
        close: {
          type: "plain_text",
          text: "Skip",
        },
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: `You selected *${moodData.emoji}* - thanks for sharing!`,
            },
          },
          {
            type: "input",
            block_id: "context_block",
            optional: true,
            element: {
              type: "plain_text_input",
              action_id: "context_input",
              multiline: true,
              placeholder: {
                type: "plain_text",
                text: "Anything you'd like to add? (optional)",
              },
            },
            label: {
              type: "plain_text",
              text: "Additional context",
            },
          },
        ],
      },
    });
  });
});

// Handle modal submission
app.view<ViewSubmitAction>(
  "mood_context_modal",
  async ({ ack, view, body, client }) => {
    await ack();

    const metadata = JSON.parse(view.private_metadata);
    const contextValue =
      view.state.values.context_block?.context_input?.value || null;

    // Get user info for display name
    const userInfo = await client.users.info({ user: body.user.id });

    // Save to Supabase
    const { error } = await supabase.from("mood_entries").insert({
      slack_user_id: body.user.id,
      slack_username: userInfo.user?.name,
      slack_display_name:
        userInfo.user?.profile?.display_name ||
        userInfo.user?.profile?.real_name,
      mood_score: metadata.score,
      mood_emoji: metadata.emoji,
      additional_context: contextValue,
      slack_team_id: body.team?.id,
    });

    if (error) {
      console.error("Error saving mood entry:", error);
      // Optionally notify user of error
      return;
    }

    // Update the original message to show completion
    const displayName = userInfo.user?.profile?.display_name || userInfo.user?.profile?.real_name || "Someone";
    if (metadata.channel_id && metadata.message_ts) {
      try {
        await client.chat.update({
          channel: metadata.channel_id,
          ts: metadata.message_ts,
          blocks: [
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: `✅ *${displayName}* is feeling ${metadata.emoji} today.`,
              },
            },
          ],
          text: `Mood recorded: ${displayName} - ${metadata.emoji}`,
        });
      } catch (updateError) {
        // Message might have been in a DM or ephemeral
        console.log("Could not update original message:", updateError);
      }
    }

    // Send confirmation DM
    await client.chat.postMessage({
      channel: body.user.id,
      text: `✅ Mood logged: ${metadata.emoji}${contextValue ? ` - "${contextValue}"` : ""}`,
    });
  }
);

// Handle modal close/skip (still save the mood, just without context)
app.view({ callback_id: "mood_context_modal", type: "view_closed" }, async ({ ack, view, body, client }) => {
  await ack();

  const metadata = JSON.parse(view.private_metadata);
  const userInfo = await client.users.info({ user: body.user.id });

  // Save to Supabase without context
  const { error } = await supabase.from("mood_entries").insert({
    slack_user_id: body.user.id,
    slack_username: userInfo.user?.name,
    slack_display_name:
      userInfo.user?.profile?.display_name ||
      userInfo.user?.profile?.real_name,
    mood_score: metadata.score,
    mood_emoji: metadata.emoji,
    additional_context: null,
    slack_team_id: body.team?.id,
  });

  if (error) {
    console.error("Error saving mood entry:", error);
  }

  // Update original message if possible
  const displayName = userInfo.user?.profile?.display_name || userInfo.user?.profile?.real_name || "Someone";
  if (metadata.channel_id && metadata.message_ts) {
    try {
      await client.chat.update({
        channel: metadata.channel_id,
        ts: metadata.message_ts,
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: `✅ *${displayName}* is feeling ${metadata.emoji} today.`,
            },
          },
        ],
        text: `Mood recorded: ${displayName} - ${metadata.emoji}`,
      });
    } catch (updateError) {
      console.log("Could not update original message:", updateError);
    }
  }
});

// Slash command to manually trigger a mood check-in
app.command("/mood", async ({ ack, respond }) => {
  await ack();
  await respond({
    blocks: buildMoodMessage(),
    response_type: "ephemeral",
  });
});

// Slash command to see your recent moods
app.command("/my-moods", async ({ ack, respond, command }) => {
  await ack();

  const { data, error } = await supabase
    .from("mood_entries")
    .select("mood_emoji, mood_score, additional_context, recorded_at")
    .eq("slack_user_id", command.user_id)
    .order("recorded_at", { ascending: false })
    .limit(7);

  if (error || !data?.length) {
    await respond({
      text: "No mood entries found yet. Use `/mood` to log your first one!",
      response_type: "ephemeral",
    });
    return;
  }

  const moodList = data
    .map((entry) => {
      const date = new Date(entry.recorded_at).toLocaleDateString("en-GB", {
        weekday: "short",
        day: "numeric",
        month: "short",
      });
      const context = entry.additional_context
        ? ` - _"${entry.additional_context}"_`
        : "";
      return `• ${date}: ${entry.mood_emoji}${context}`;
    })
    .join("\n");

  const avgMood =
    data.reduce((sum, e) => sum + e.mood_score, 0) / data.length;

  await respond({
    blocks: [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: `*Your recent moods* (last ${data.length} entries)\nAverage: ${avgMood.toFixed(1)}/5\n\n${moodList}`,
        },
      },
    ],
    response_type: "ephemeral",
  });
});

// Function to send daily check-ins (call this from a cron job)
export async function sendDailyCheckIns(channelId?: string, userIds?: string[]) {
  const token = process.env.SLACK_BOT_TOKEN!;
  const { WebClient } = await import("@slack/web-api");
  const webClient = new WebClient(token);

  // Option 1: Send to a channel
  if (channelId) {
    await webClient.chat.postMessage({
      channel: channelId,
      blocks: buildMoodMessage(),
      text: "How are you feeling today?",
    });
    console.log(`Sent mood check-in to channel ${channelId}`);
  }

  // Option 2: Send DMs to specific users
  if (userIds?.length) {
    for (const userId of userIds) {
      try {
        await webClient.chat.postMessage({
          channel: userId,
          blocks: buildMoodMessage(),
          text: "How are you feeling today?",
        });
        console.log(`Sent mood check-in to user ${userId}`);
      } catch (error) {
        console.error(`Failed to send to ${userId}:`, error);
      }
    }
  }
}

// Start the app
(async () => {
  await app.start();
  console.log("⚡️ Mood Tracker bot is running!");
})();
