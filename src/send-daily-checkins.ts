/**
 * Daily Mood Check-in Trigger
 * 
 * Run this script via a cron job to send daily mood check-ins.
 * 
 * Usage:
 *   npx ts-node src/send-daily-checkins.ts
 * 
 * Or set up as a Vercel Cron, GitHub Action, or any scheduler.
 */

import { WebClient } from "@slack/web-api";
import { KnownBlock } from "@slack/types";
import "dotenv/config";

// Configuration - update these for your workspace
const CONFIG = {
  // Option 1: Send to a specific channel (e.g., #team-checkins)
  channelId: process.env.MOOD_CHANNEL_ID || null,
  
  // Option 2: Send DMs to specific user IDs
  // Get user IDs from Slack (click profile > More > Copy member ID)
  userIds: process.env.MOOD_USER_IDS?.split(",").filter(Boolean) || [],
  
  // Skip weekends?
  skipWeekends: process.env.SKIP_WEEKENDS === "true",
};

const MOODS = [
  { score: 1, emoji: "😭", action_id: "mood_1" },
  { score: 2, emoji: "☹️", action_id: "mood_2" },
  { score: 3, emoji: "😐", action_id: "mood_3" },
  { score: 4, emoji: "🙂", action_id: "mood_4" },
  { score: 5, emoji: "😄", action_id: "mood_5" },
];

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

async function main() {
  // Check for weekend skip
  if (CONFIG.skipWeekends) {
    const day = new Date().getDay();
    if (day === 0 || day === 6) {
      console.log("Skipping - it's the weekend!");
      return;
    }
  }

  const client = new WebClient(process.env.SLACK_BOT_TOKEN);
  const blocks = buildMoodMessage();

  // Send to channel
  if (CONFIG.channelId) {
    try {
      await client.chat.postMessage({
        channel: CONFIG.channelId,
        blocks,
        text: "How are you feeling today?",
      });
      console.log(`✅ Sent mood check-in to channel ${CONFIG.channelId}`);
    } catch (error) {
      console.error(`❌ Failed to send to channel:`, error);
    }
  }

  // Send DMs
  for (const userId of CONFIG.userIds) {
    try {
      await client.chat.postMessage({
        channel: userId,
        blocks,
        text: "How are you feeling today?",
      });
      console.log(`✅ Sent mood check-in to user ${userId}`);
    } catch (error) {
      console.error(`❌ Failed to send to ${userId}:`, error);
    }
  }

  if (!CONFIG.channelId && !CONFIG.userIds.length) {
    console.log("⚠️  No channel or users configured. Set MOOD_CHANNEL_ID or MOOD_USER_IDS in .env");
  }
}

main().catch(console.error);
