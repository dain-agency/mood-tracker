import { WebClient } from "@slack/web-api";
import { KnownBlock } from "@slack/types";
import type { VercelRequest, VercelResponse } from "@vercel/node";
import { randomUUID } from "node:crypto";
import { wrapWithHeartbeat } from "../../src/lib/monitoring/heartbeat-client";

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

interface CheckinResult {
  message: string;
  totalChannelMembers?: number;
  skippedMembers?: { id: string; reason: string }[];
  results?: { userId: string; success: boolean; error?: string }[];
}

async function runDailyCheckin(channelId: string): Promise<CheckinResult> {
  const client = new WebClient(process.env.SLACK_BOT_TOKEN);
  const blocks = buildMoodMessage();
  const results: { userId: string; success: boolean; error?: string }[] = [];

  // Fetch all members of the channel (handles pagination).
  // A failure here means we couldn't even start the work — throw so the
  // outer wrapWithHeartbeat emits a 'failed' beat with the error message.
  let allMembers: string[] = [];
  let cursor: string | undefined;
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

  // Filter out bots by checking user info
  const humanMembers: string[] = [];
  const skippedMembers: { id: string; reason: string }[] = [];

  for (const memberId of allMembers) {
    try {
      const userInfo = await client.users.info({ user: memberId });
      if (!userInfo.user) {
        skippedMembers.push({ id: memberId, reason: "no user info" });
      } else if (userInfo.user.is_bot) {
        skippedMembers.push({ id: memberId, reason: "is_bot" });
      } else if (userInfo.user.deleted) {
        skippedMembers.push({ id: memberId, reason: "deleted" });
      } else {
        humanMembers.push(memberId);
      }
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      skippedMembers.push({ id: memberId, reason: `error: ${message}` });
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
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      results.push({ userId, success: false, error: message });
    }
  }

  return {
    message: `Daily check-in sent to ${results.filter(r => r.success).length}/${humanMembers.length} members`,
    totalChannelMembers: allMembers.length,
    skippedMembers,
    results,
  };
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Verify cron secret to prevent unauthorized access. No heartbeat — an
  // unauthorised hit isn't a cron run.
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  // Check for weekend skip (using UK timezone). Same logic: not a real run,
  // so we don't heartbeat. The Monitoring Hub treats the weekday schedule
  // as the source of truth.
  if (process.env.SKIP_WEEKENDS === "true") {
    const ukDate = new Date().toLocaleString("en-GB", { timeZone: "Europe/London", weekday: "short" });
    if (ukDate === "Sat" || ukDate === "Sun") {
      return res.status(200).json({ message: "Skipped - weekend" });
    }
  }

  const channelId = process.env.MOOD_CHANNEL_ID;
  if (!channelId) {
    return res.status(200).json({
      message: "No channel configured. Set MOOD_CHANNEL_ID to specify which channel's members should receive DMs.",
      results: [],
    });
  }

  // Heartbeat wrapper. Emits `started` → real work → `completed` (success)
  // or `failed` (thrown error) to the dain-os Monitoring Hub. Heartbeat
  // failures are swallowed by the client and never block the cron itself.
  const monitoringUrl = process.env.MONITORING_HEARTBEAT_URL;
  const monitoringSecret = process.env.MONITORING_HEARTBEAT_SECRET;
  if (!monitoringUrl || !monitoringSecret) {
    // Monitoring not configured — run unmonitored. Still a valid cron exec.
    try {
      const result = await runDailyCheckin(channelId);
      return res.status(200).json(result);
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      return res.status(500).json({ message: "Failed to fetch channel members", error: message });
    }
  }

  try {
    const result = await wrapWithHeartbeat(
      {
        endpoint: monitoringUrl,
        secret: monitoringSecret,
        provider: "vercel",
        // VERCEL_PROJECT_ID is auto-injected by Vercel at runtime. Falling
        // back to the literal so local runs still target a stable source row.
        projectRef: process.env.VERCEL_PROJECT_ID ?? "prj_SKzHtTyQvaJk00SiSPxp2A6kLRw5",
        externalId: "/api/cron/daily-checkin",
        externalRunId: randomUUID(),
        displayName: "Daily mood check-in",
        scheduleExpression: "0 9 * * 1-5",
        onError: (phase, err) => {
          console.error(`[monitoring] heartbeat ${phase} failed`, err);
        },
      },
      () => runDailyCheckin(channelId),
    );
    return res.status(200).json(result);
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return res.status(500).json({ message: "Failed to fetch channel members", error: message });
  }
}
