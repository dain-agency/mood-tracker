# Dain Mood Tracker 🎭

A simple Slack bot for daily team mood check-ins, storing responses in Supabase.

## Features

- **Daily mood check-ins** with 5 emoji options (😭 ☹️ 😐 🙂 😄)
- **Optional context** - users can add notes about why they feel that way
- **Slack commands**:
  - `/mood` - manually trigger a mood check-in
  - `/my-moods` - view your last 7 mood entries
- **Supabase storage** with built-in analytics views
- **Flexible delivery** - send to channels or individual DMs

## Quick Start

### 1. Create the Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and click **Create New App**
2. Choose **From scratch** and name it "Mood Tracker"
3. Select your workspace

#### Configure OAuth & Permissions

Navigate to **OAuth & Permissions** and add these **Bot Token Scopes**:

- `chat:write` - Send messages
- `commands` - Handle slash commands
- `users:read` - Get user display names
- `im:write` - Send DMs

#### Enable Socket Mode

Navigate to **Socket Mode** and toggle it on. Create an **App-Level Token** with the `connections:write` scope. Save this token (starts with `xapp-`).

#### Create Slash Commands

Navigate to **Slash Commands** and create:

| Command | Description | Usage Hint |
|---------|-------------|------------|
| `/mood` | Check in with your mood | |
| `/my-moods` | View your recent mood entries | |

#### Enable Interactivity

Navigate to **Interactivity & Shortcuts** and toggle it on. (Socket Mode handles the request URL automatically.)

#### Install the App

Navigate to **Install App** and click **Install to Workspace**. Copy the **Bot User OAuth Token** (starts with `xoxb-`).

### 2. Set Up Supabase

Run the migration in your DainOS Supabase project:

```sql
-- Copy contents of supabase/migrations/001_create_mood_entries.sql
-- and run in Supabase SQL Editor
```

Get your Supabase credentials from **Settings > API**:
- **Project URL**
- **Service Role Key** (under Project API keys)

### 3. Configure Environment

```bash
cp .env.example .env
```

Fill in your `.env`:

```env
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_SIGNING_SECRET=your-signing-secret
SLACK_APP_TOKEN=xapp-your-app-token
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
MOOD_CHANNEL_ID=C0123456789
MOOD_USER_IDS=U0123456789,U9876543210
SKIP_WEEKENDS=true
```

**Finding Slack IDs:**
- **Channel ID**: Right-click channel > View channel details > scroll to bottom
- **User ID**: Click user profile > More (⋯) > Copy member ID

### 4. Run the Bot

```bash
# Install dependencies
npm install

# Development (with hot reload)
npm run dev

# Production
npm run build
npm start
```

### 5. Set Up Daily Triggers

The bot needs to be triggered daily to send check-ins. Options:

#### Option A: GitHub Actions (recommended for simplicity)

Create `.github/workflows/daily-mood.yml`:

```yaml
name: Daily Mood Check-in
on:
  schedule:
    - cron: '0 9 * * 1-5'  # 9am UTC, Mon-Fri
  workflow_dispatch:  # Manual trigger

jobs:
  send:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run send-checkins
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
          MOOD_CHANNEL_ID: ${{ secrets.MOOD_CHANNEL_ID }}
          # Or use MOOD_USER_IDS for DMs
```

#### Option B: Vercel Cron (if hosting on Vercel)

See the `vercel.json` example in this repo.

#### Option C: Any cron service

Just run `npm run send-checkins` on your schedule.

## Hosting the Bot

The main bot (`npm start`) needs to run continuously to handle button clicks and modals. Options:

1. **Railway** - Easy Node.js hosting, free tier available
2. **Render** - Similar to Railway
3. **Fly.io** - Great for small apps
4. **Your own server** - PM2 + any VPS
5. **Vercel** - Serverless (requires some restructuring)

## Data & Analytics

### Query Examples

```sql
-- Team mood trend (last 30 days)
SELECT 
  DATE(recorded_at) as date,
  ROUND(AVG(mood_score)::numeric, 2) as avg_mood,
  COUNT(*) as responses
FROM mood_entries
WHERE recorded_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(recorded_at)
ORDER BY date;

-- Individual patterns
SELECT 
  slack_display_name,
  ROUND(AVG(mood_score)::numeric, 2) as avg_mood,
  COUNT(*) as total_entries
FROM mood_entries
GROUP BY slack_user_id, slack_display_name;

-- Low mood alerts (for follow-up)
SELECT * FROM mood_entries
WHERE mood_score <= 2
  AND recorded_at > NOW() - INTERVAL '7 days'
ORDER BY recorded_at DESC;
```

### Built-in View

The migration includes a `mood_daily_summary` view:

```sql
SELECT * FROM mood_daily_summary ORDER BY date DESC LIMIT 14;
```

## Customisation Ideas

- **Custom emojis** - Update the `MOODS` array in `app.ts`
- **Weekly summaries** - Add a scheduled job to post team stats
- **Manager notifications** - Alert when team mood drops
- **Integration with DainOS** - Add a mood dashboard

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Bot not responding to clicks | Check Socket Mode is enabled and app is running |
| "not_in_channel" error | Invite the bot to the channel: `/invite @Mood Tracker` |
| Modal not opening | Ensure `trigger_id` is being passed (check Slack app logs) |
| Data not saving | Check Supabase credentials and table exists |

## Project Structure

```
mood-tracker/
├── src/
│   ├── app.ts                 # Main Slack bot
│   └── send-daily-checkins.ts # Cron trigger script
├── supabase/
│   └── migrations/
│       └── 001_create_mood_entries.sql
├── .env.example
├── package.json
├── tsconfig.json
└── README.md
```
