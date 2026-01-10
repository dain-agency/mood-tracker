# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Slack bot for daily team mood check-ins that stores responses in Supabase. Uses Socket Mode for real-time interaction handling.

## Commands

```bash
# Install dependencies
npm install

# Development (with hot reload)
npm run dev

# Production build
npm run build
npm start

# Send daily check-ins (run via cron/scheduler)
npm run send-checkins
```

## Architecture

### Two Entry Points

1. **`src/app.ts`** - Main Slack bot (runs continuously)
   - Handles button clicks, modals, and slash commands via Socket Mode
   - Must be running for interactive features to work

2. **`src/send-daily-checkins.ts`** - Standalone trigger script
   - Sends mood check-in messages to channels/users
   - Run via cron job, GitHub Actions, or scheduler
   - Does not require the main bot to be running

### Data Flow

1. User receives mood check-in message (5 emoji buttons)
2. Button click opens a modal for optional context
3. Response saved to `mood_entries` table in Supabase
4. Original message updated to show completion

### Key Configuration

Environment variables in `.env`:
- `MOOD_CHANNEL_ID` - Send check-ins to a channel
- `MOOD_USER_IDS` - Send DMs to specific users (comma-separated)
- `SKIP_WEEKENDS` - Skip Saturday/Sunday when true

### Database

Single table `mood_entries` with:
- `mood_score` (1-5)
- `mood_emoji`
- `additional_context` (optional)
- `slack_user_id`, `slack_display_name`

View `mood_daily_summary` provides aggregated daily stats.
