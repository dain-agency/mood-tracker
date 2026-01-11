import { WebClient } from "@slack/web-api";
import { KnownBlock } from "@slack/types";
import type { VercelRequest, VercelResponse } from "@vercel/node";

// Mood configuration
const MOODS = [
  { score: 1, emoji: "😭", action_id: "mood_1" },
  { score: 2, emoji: "☹️", action_id: "mood_2" },
  { score: 3, emoji: "😐", action_id: "mood_3" },
  { score: 4, emoji: "🙂", action_id: "mood_4" },
  { score: 5, emoji: "😄", action_id: "mood_5" },
];

// Get time-appropriate greeting (UK timezone)
function getGreeting(): string {
  const ukTime = new Date().toLocaleString("en-GB", { timeZone: "Europe/London", hour: "numeric", hour12: false });
  const hour = parseInt(ukTime, 10);
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

function buildMoodMessage(): KnownBlock[] {
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
        value: JSON.stringify({ score: mood.score, emoji: mood.emoji }),
        action_id: mood.action_id,
      })),
    },
  ];
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Verify cron secret to prevent unauthorized access
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  // Check for weekend skip
  if (process.env.SKIP_WEEKENDS === "true") {
    const ukDate = new Date().toLocaleString("en-GB", { timeZone: "Europe/London", weekday: "short" });
    if (ukDate === "Sat" || ukDate === "Sun") {
      return res.status(200).json({ message: "Skipped - weekend" });
    }
  }

  const client = new WebClient(process.env.SLACK_BOT_TOKEN);
  const blocks = buildMoodMessage();

  const results: { userId: string; success: boolean; error?: string }[] = [];

  // Send to channel if configured
  const channelId = process.env.MOOD_CHANNEL_ID;
  if (channelId) {
    try {
      await client.chat.postMessage({
        channel: channelId,
        blocks,
        text: "How are you feeling today?",
      });
      results.push({ userId: `channel:${channelId}`, success: true });
    } catch (error: any) {
      results.push({ userId: `channel:${channelId}`, success: false, error: error.message });
    }
  }

  // Send DMs to specific users
  const userIds = process.env.MOOD_USER_IDS?.split(",").filter(Boolean) || [];
  for (const userId of userIds) {
    try {
      await client.chat.postMessage({
        channel: userId.trim(),
        blocks,
        text: "How are you feeling today?",
      });
      results.push({ userId: userId.trim(), success: true });
    } catch (error: any) {
      results.push({ userId: userId.trim(), success: false, error: error.message });
    }
  }

  if (!channelId && userIds.length === 0) {
    return res.status(200).json({
      message: "No channel or users configured. Set MOOD_CHANNEL_ID or MOOD_USER_IDS.",
      results: []
    });
  }

  return res.status(200).json({
    message: "Daily check-in sent",
    results
  });
}
