ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS action_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS action_id BIGINT,
    ADD COLUMN IF NOT EXISTS metadata JSONB,
    ADD COLUMN IF NOT EXISTS read_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL';

CREATE INDEX IF NOT EXISTS idx_notifications_user_deleted_read_created
    ON notifications(user_id, is_deleted, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_action
    ON notifications(user_id, type, action_type, action_id)
    WHERE is_deleted = FALSE AND action_type IS NOT NULL AND action_id IS NOT NULL;
