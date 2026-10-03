-- Existing OTPs have no purpose and existing JWTs have no session binding.
-- Deliberately invalidate them: users must request a new code / sign in again.
ALTER TABLE users ALTER COLUMN otp TYPE VARCHAR(100);
ALTER TABLE users ADD COLUMN otp_purpose VARCHAR(30);
ALTER TABLE users ADD COLUMN token_version BIGINT NOT NULL DEFAULT 0;
UPDATE users SET otp = NULL, otp_expiry = NULL, otp_attempts = 0, otp_locked_until = NULL;

CREATE TABLE refresh_sessions (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    family_id UUID NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed BOOLEAN NOT NULL DEFAULT FALSE,
    revoked BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_refresh_sessions_user ON refresh_sessions(user_id);
CREATE INDEX idx_refresh_sessions_family ON refresh_sessions(family_id);
