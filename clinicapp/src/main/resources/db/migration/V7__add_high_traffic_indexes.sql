-- Indexes for the app's most frequent authenticated read paths.

CREATE INDEX IF NOT EXISTS idx_appointments_user_deleted_date_time
    ON appointments(user_id, is_deleted, appointment_date DESC, appointment_time DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_deleted_created
    ON notifications(user_id, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_protocols_user_deleted_created
    ON treatment_protocols(user_id, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_protocols_user_status_deleted
    ON treatment_protocols(user_id, status, is_deleted);

CREATE INDEX IF NOT EXISTS idx_sessions_user_deleted_status_date_time
    ON treatment_sessions(user_id, is_deleted, status, session_date, session_time);

CREATE INDEX IF NOT EXISTS idx_sessions_protocol_deleted_date_time
    ON treatment_sessions(protocol_id, is_deleted, session_date, session_time);
