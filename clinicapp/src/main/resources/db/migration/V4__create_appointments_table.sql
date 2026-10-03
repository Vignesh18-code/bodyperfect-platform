CREATE TABLE IF NOT EXISTS appointments (

    id                  BIGSERIAL       PRIMARY KEY,

    -- Link to user (1-to-many, name/email/phone live in users table)
    user_id             BIGINT          NOT NULL,

    -- Appointment details
    appointment_date    DATE            NOT NULL,
    appointment_time    TIME            NOT NULL,
    branch              VARCHAR(30)     NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'PENDING',

    -- Optional patient note
    note                VARCHAR(500),

    -- Soft delete
    is_deleted          BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP,

    -- Foreign key
    CONSTRAINT fk_appointments_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Indexes
CREATE INDEX idx_appointments_user_id   ON appointments(user_id);
CREATE INDEX idx_appointments_date_time ON appointments(user_id, appointment_date, appointment_time) WHERE is_deleted = FALSE;
CREATE INDEX idx_appointments_status    ON appointments(user_id, status) WHERE is_deleted = FALSE;
