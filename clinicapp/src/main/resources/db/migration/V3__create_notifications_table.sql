CREATE TABLE IF NOT EXISTS notifications (

    id                  BIGSERIAL       PRIMARY KEY,

    -- Link to user
    user_id             BIGINT          NOT NULL,

    -- Notification content
    title               VARCHAR(200)    NOT NULL,
    message             VARCHAR(1000)   NOT NULL,
    type                VARCHAR(30)     NOT NULL DEFAULT 'GENERAL',

    -- Read status
    is_read             BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Soft delete
    is_deleted          BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP,

    -- Foreign key
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Indexes
CREATE INDEX idx_notifications_user_id    ON notifications(user_id);
CREATE INDEX idx_notifications_is_read    ON notifications(user_id, is_read) WHERE is_deleted = FALSE;
CREATE INDEX idx_notifications_created_at ON notifications(user_id, created_at DESC) WHERE is_deleted = FALSE;
