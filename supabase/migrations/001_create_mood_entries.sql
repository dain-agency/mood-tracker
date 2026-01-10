-- Mood Tracker Schema for DainOS
-- Run this in your Supabase SQL editor or as a migration

-- Create the mood_entries table
CREATE TABLE IF NOT EXISTS mood_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Slack user info
    slack_user_id TEXT NOT NULL,
    slack_username TEXT,
    slack_display_name TEXT,
    
    -- Mood data
    mood_score INTEGER NOT NULL CHECK (mood_score >= 1 AND mood_score <= 5),
    mood_emoji TEXT NOT NULL,
    additional_context TEXT,
    
    -- Timestamps
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Optional: link to team/workspace
    slack_team_id TEXT
);

-- Index for querying by user and date
CREATE INDEX idx_mood_entries_user_date 
ON mood_entries (slack_user_id, recorded_at DESC);

-- Index for team-wide queries
CREATE INDEX idx_mood_entries_team_date 
ON mood_entries (slack_team_id, recorded_at DESC);

-- Optional: Create a view for daily summaries
CREATE OR REPLACE VIEW mood_daily_summary AS
SELECT 
    DATE(recorded_at) as date,
    slack_team_id,
    COUNT(*) as total_responses,
    ROUND(AVG(mood_score)::numeric, 2) as avg_mood,
    COUNT(*) FILTER (WHERE mood_score >= 4) as positive_count,
    COUNT(*) FILTER (WHERE mood_score <= 2) as negative_count
FROM mood_entries
GROUP BY DATE(recorded_at), slack_team_id
ORDER BY date DESC;

-- Row Level Security (optional but recommended)
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;

-- Policy: Service role can do everything (for your app)
CREATE POLICY "Service role full access" ON mood_entries
    FOR ALL
    USING (true)
    WITH CHECK (true);

COMMENT ON TABLE mood_entries IS 'Daily mood check-in entries from Slack';
COMMENT ON COLUMN mood_entries.mood_score IS '1=😭, 2=☹️, 3=😐, 4=🙂, 5=😄';
