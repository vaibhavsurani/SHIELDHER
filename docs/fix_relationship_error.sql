-- ==========================================
-- FIX MISSING RELATIONSHIP ERROR
-- Run this in Supabase SQL Editor
-- ==========================================

-- The error "Could not find a relationship between 'live_locations' and 'user_profiles'"
-- happens because Supabase needs an explicit Foreign Key to join tables automatically.

-- 1. Add Foreign Key from live_locations.user_id to user_profiles.user_id
-- We already have a FK to auth.users, but for the join to work with user_profiles,
-- we should make sure the relationship is clear.

-- Since both tables employ user_id as PK and FK to auth.users, they are 1:1.
-- However, PostgREST sometimes needs an explicit FK between the two tables to allow embedding.

ALTER TABLE live_locations
DROP CONSTRAINT IF EXISTS live_locations_user_id_fkey_profiles;

-- Add explicit FK to user_profiles
ALTER TABLE live_locations
ADD CONSTRAINT live_locations_user_id_fkey_profiles
FOREIGN KEY (user_id)
REFERENCES user_profiles (user_id)
ON DELETE CASCADE;

-- 2. Refresh the schema cache (Supabase does this automatically usually, but good to know)
NOTIFY pgrst, 'reload config';
