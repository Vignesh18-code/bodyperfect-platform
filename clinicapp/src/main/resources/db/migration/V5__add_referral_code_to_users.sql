-- Step 1: Add column as nullable first (for backfill)
ALTER TABLE users ADD COLUMN referral_code VARCHAR(10);

-- Step 2: Backfill existing users with unique generated codes
-- Format: BP + 6 uppercase alphanumeric chars (deterministic from id)
UPDATE users
SET referral_code = 'BP' || UPPER(SUBSTRING(MD5(id::TEXT || 'bodyperfect-salt'), 1, 6))
WHERE referral_code IS NULL;

-- Step 3: Now enforce NOT NULL + unique
ALTER TABLE users ALTER COLUMN referral_code SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT uk_users_referral_code UNIQUE (referral_code);

-- Step 4: Index for lookups (refer-a-friend feature)
CREATE INDEX idx_users_referral_code ON users(referral_code);
