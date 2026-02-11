-- ==========================================
-- SHIELDHER - LIVE LOCATIONS FIX
-- Run this in Supabase SQL Editor
-- ==========================================

-- 1. Ensure the live_locations table exists with correct structure
-- (This is safe to run even if it already exists)
CREATE TABLE IF NOT EXISTS live_locations (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  latitude DOUBLE PRECISION NOT NULL DEFAULT 0,
  longitude DOUBLE PRECISION NOT NULL DEFAULT 0,
  speed DOUBLE PRECISION DEFAULT 0,
  heading DOUBLE PRECISION DEFAULT 0,
  is_live BOOLEAN DEFAULT false,
  is_helper BOOLEAN DEFAULT false,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE live_locations ENABLE ROW LEVEL SECURITY;

-- 3. Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can insert their own location" ON live_locations;
DROP POLICY IF EXISTS "Users can update their own location" ON live_locations;
DROP POLICY IF EXISTS "Bubble members can view each others locations" ON live_locations;
DROP POLICY IF EXISTS "Anyone can read live locations" ON live_locations;
DROP POLICY IF EXISTS "Users can manage own location" ON live_locations;

-- 4. Create RLS Policies

-- Policy: Users can insert/upsert their own location
CREATE POLICY "Users can insert their own location"
  ON live_locations
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own location
CREATE POLICY "Users can update their own location"
  ON live_locations
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Bubble members can view each other's locations
-- This allows a user to see locations of others who share at least one bubble with them
CREATE POLICY "Bubble members can view each others locations"
  ON live_locations
  FOR SELECT
  USING (
    -- User can see their own location
    auth.uid() = user_id
    OR
    -- User can see locations of people in their bubbles
    user_id IN (
      SELECT bm2.user_id
      FROM bubble_members bm1
      JOIN bubble_members bm2 ON bm1.bubble_id = bm2.bubble_id
      WHERE bm1.user_id = auth.uid()
    )
    OR
    -- Anyone can see helpers who are live
    (is_live = true AND is_helper = true)
  );

-- 5. Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_live_locations_user_id ON live_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_live_locations_is_live ON live_locations(is_live);

-- 6. Ensure bubble_members also has proper RLS for consistency
ALTER TABLE bubble_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read bubble members" ON bubble_members;
DROP POLICY IF EXISTS "Users can join bubbles" ON bubble_members;
DROP POLICY IF EXISTS "Users can leave bubbles" ON bubble_members;

CREATE POLICY "Anyone can read bubble members"
  ON bubble_members
  FOR SELECT
  USING (true);

CREATE POLICY "Users can join bubbles"
  ON bubble_members
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can leave bubbles"
  ON bubble_members
  FOR DELETE
  USING (auth.uid() = user_id);

-- 7. Ensure user_profiles can be read by anyone (for display names)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;

CREATE POLICY "Anyone can read profiles"
  ON user_profiles
  FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own profile"
  ON user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  USING (auth.uid() = user_id);

-- ==========================================
-- DONE! After running this:
-- 1. Users can save their own location
-- 2. Users can see locations of others in same bubbles
-- 3. Users can see all live helpers
-- ==========================================
