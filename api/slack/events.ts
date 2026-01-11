import { App, ExpressReceiver, BlockAction, ViewSubmitAction } from "@slack/bolt";
import { KnownBlock } from "@slack/types";
import { createClient } from "@supabase/supabase-js";
import type { VercelRequest, VercelResponse } from "@vercel/node";

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

// Mood configuration
const MOODS = [
  { score: 1, emoji: "😭", label: "Awful", action_id: "mood_1" },
  { score: 2, emoji: "☹️", label: "Not great", action_id: "mood_2" },
  { score: 3, emoji: "😐", label: "Okay", action_id: "mood_3" },
  { score: 4, emoji: "🙂", label: "Good", action_id: "mood_4" },
  { score: 5, emoji: "😄", label: "Great", action_id: "mood_5" },
] as const;

// Get time-appropriate greeting
function getGreeting(): string {
  // Use UK timezone
  const ukTime = new Date().toLocaleString("en-GB", { timeZone: "Europe/London", hour: "numeric", hour12: false });
  const hour = parseInt(ukTime, 10);
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

// Build the mood check-in message blocks
function buildMoodMessage(sourceChannelId?: string, responseUrl?: string): KnownBlock[] {
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
        type: "button" as const,
        text: {
          type: "plain_text" as const,
          text: mood.emoji,
          emoji: true,
        },
        value: JSON.stringify({ score: mood.score, emoji: mood.emoji, source_channel_id: sourceChannelId, response_url: responseUrl }),
        action_id: mood.action_id,
      })),
    },
  ];
}

// Create Express receiver for HTTP mode
const receiver = new ExpressReceiver({
  signingSecret: process.env.SLACK_SIGNING_SECRET!,
  processBeforeResponse: true,
});

// Initialize Slack app with HTTP receiver
const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  receiver,
});

// Handle mood button clicks
MOODS.forEach((mood) => {
  app.action<BlockAction>(mood.action_id, async ({ ack, body, client }) => {
    await ack();

    const moodData = JSON.parse(
      (body as any).actions[0].value
    ) as { score: number; emoji: string; source_channel_id?: string; response_url?: string };

    const channelId = moodData.source_channel_id || (body as any).channel?.id;

    await client.views.open({
      trigger_id: (body as any).trigger_id,
      view: {
        type: "modal",
        callback_id: "mood_context_modal",
        private_metadata: JSON.stringify({
          score: moodData.score,
          emoji: moodData.emoji,
          channel_id: channelId,
          message_ts: (body as any).message?.ts,
          response_url: moodData.response_url,
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
      return;
    }

    const displayName = userInfo.user?.profile?.display_name || userInfo.user?.profile?.real_name || "Someone";
    let messageUpdated = false;

    // Try to update original message
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
        messageUpdated = true;
      } catch (updateError) {
        console.log("Could not update original message (likely ephemeral)");
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
            body: JSON.stringify({
              text: confirmationText,
              response_type: "ephemeral",
            }),
          });
        } catch (responseUrlError) {
          console.log("Could not send response_url confirmation:", responseUrlError);
        }
      } else if (metadata.channel_id) {
        const isDM = metadata.channel_id.startsWith("D");
        try {
          if (isDM) {
            await client.chat.postMessage({
              channel: metadata.channel_id,
              text: confirmationText,
            });
          } else {
            await client.chat.postEphemeral({
              channel: metadata.channel_id,
              user: body.user.id,
              text: confirmationText,
            });
          }
        } catch (confirmError) {
          console.log("Could not send confirmation:", confirmError);
        }
      }
    }

    // Send confirmation DM (app messages)
    await client.chat.postMessage({
      channel: body.user.id,
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
      } catch (channelError) {
        console.log("Could not post to mood channel:", channelError);
      }
    }
  }
);

// Handle modal close/skip
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

  const displayName = userInfo.user?.profile?.display_name || userInfo.user?.profile?.real_name || "Someone";
  let messageUpdated = false;

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
      messageUpdated = true;
    } catch (updateError) {
      console.log("Could not update original message (likely ephemeral)");
    }
  }

  if (!messageUpdated) {
    const confirmationText = `✅ *${displayName}*, your mood has been logged: ${metadata.emoji}`;

    if (metadata.response_url) {
      try {
        await fetch(metadata.response_url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            text: confirmationText,
            response_type: "ephemeral",
          }),
        });
      } catch (responseUrlError) {
        console.log("Could not send response_url confirmation:", responseUrlError);
      }
    } else if (metadata.channel_id) {
      const isDM = metadata.channel_id.startsWith("D");
      try {
        if (isDM) {
          await client.chat.postMessage({
            channel: metadata.channel_id,
            text: confirmationText,
          });
        } else {
          await client.chat.postEphemeral({
            channel: metadata.channel_id,
            user: body.user.id,
            text: confirmationText,
          });
        }
      } catch (confirmError) {
        console.log("Could not send confirmation:", confirmError);
      }
    }
  }

  // Post to mood channel if configured
  const moodChannelId = process.env.MOOD_CHANNEL_ID;
  if (moodChannelId) {
    try {
      await client.chat.postMessage({
        channel: moodChannelId,
        text: `*${displayName}* is feeling ${metadata.emoji} today`,
      });
    } catch (channelError) {
      console.log("Could not post to mood channel:", channelError);
    }
  }
});

// Slash command: /mood
app.command("/mood", async ({ ack, respond, command, payload }) => {
  await ack();
  await respond({
    blocks: buildMoodMessage(command.channel_id, payload.response_url),
    response_type: "ephemeral",
  });
});

// Slash command: /my-moods
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

  const avgMood = data.reduce((sum, e) => sum + e.mood_score, 0) / data.length;

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

// Export Vercel handler
export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Handle Slack URL verification challenge
  if (req.body?.type === "url_verification") {
    return res.status(200).json({ challenge: req.body.challenge });
  }

  // Pass to Express receiver
  await receiver.app(req, res);
}
