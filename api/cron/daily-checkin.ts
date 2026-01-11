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

  // Check for weekend skip (using UK timezone)
  if (process.env.SKIP_WEEKENDS === "true") {
    const ukDate = new Date().toLocaleString("en-GB", { timeZone: "Europe/London", weekday: "short" });
    if (ukDate === "Sat" || ukDate === "Sun") {
      return res.status(200).json({ message: "Skipped - weekend" });
    }
  }

  const client = new WebClient(process.env.SLACK_BOT_TOKEN);
  const blocks = buildMoodMessage();
  const results: { userId: string; success: boolean; error?: string }[] = [];

  const channelId = process.env.MOOD_CHANNEL_ID;

  if (!channelId) {
    return res.status(200).json({
      message: "No channel configured. Set MOOD_CHANNEL_ID to specify which channel's members should receive DMs.",
      results: []
    });
  }

  // Fetch all members of the channel (handles pagination)
  let allMembers: string[] = [];
  let cursor: string | undefined;

  try {
    do {
      const response = await client.conversations.members({
        channel: channelId,
        cursor,
        limit: 200,
      });

      if (response.members) {
        allMembers = allMembers.concat(response.members);
      }
      cursor = response.response_metadata?.next_cursor;
    } while (cursor);
  } catch (error: any) {
    return res.status(500).json({
      message: "Failed to fetch channel members",
      error: error.message
    });
  }

  // Filter out bots by checking user info
  const humanMembers: string[] = [];
  for (const memberId of allMembers) {
    try {
      const userInfo = await client.users.info({ user: memberId });
      if (userInfo.user && !userInfo.user.is_bot && !userInfo.user.deleted) {
        humanMembers.push(memberId);
      }
    } catch (error) {
      // Skip users we can't fetch info for
      console.log(`Could not fetch info for user ${memberId}`);
    }
  }

  // Send DM to each human member
  for (const userId of humanMembers) {
    try {
      await client.chat.postMessage({
        channel: userId,
        blocks,
        text: "How are you feeling today?",
      });
      results.push({ userId, success: true });
    } catch (error: any) {
      results.push({ userId, success: false, error: error.message });
    }
  }

  return res.status(200).json({
    message: `Daily check-in sent to ${results.filter(r => r.success).length}/${humanMembers.length} members`,
    results
  });
}
