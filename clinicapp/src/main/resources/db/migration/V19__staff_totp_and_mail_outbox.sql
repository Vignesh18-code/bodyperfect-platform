CREATE TABLE staff_totp (
 user_id BIGINT PRIMARY KEY REFERENCES users(id), secret TEXT NOT NULL,
 enrolled BOOLEAN NOT NULL DEFAULT FALSE, last_counter BIGINT NOT NULL DEFAULT -1,
 attempts INTEGER NOT NULL DEFAULT 0, locked_until TIMESTAMPTZ,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Force existing staff sessions to reauthenticate after MFA rollout.
UPDATE users SET token_version=token_version+1 WHERE role IN ('STAFF','ADMIN');
CREATE TABLE mail_outbox (
 id BIGSERIAL PRIMARY KEY, recipient VARCHAR(255) NOT NULL, payload TEXT,
 state VARCHAR(20) NOT NULL DEFAULT 'PENDING', attempts INTEGER NOT NULL DEFAULT 0,
 next_attempt TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 expires_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP+INTERVAL '5 minutes',
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_mail_pending ON mail_outbox(state,next_attempt);
