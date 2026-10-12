ALTER TABLE staff_totp
 ADD COLUMN pending_secret TEXT,
 ADD COLUMN pending_expires_at TIMESTAMPTZ,
 ADD COLUMN pending_attempts INTEGER NOT NULL DEFAULT 0;
