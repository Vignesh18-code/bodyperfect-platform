-- A closed account keeps a non-identifying FK tombstone; clinical records are never
-- erased by account deletion. Identifying clinical metadata is encrypted separately.
CREATE TABLE account_closures (
 patient_id BIGINT PRIMARY KEY REFERENCES users(id),
 request_id BIGINT NOT NULL UNIQUE REFERENCES privacy_requests(id),
 closed_by BIGINT NOT NULL REFERENCES users(id),
 closed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 original_created_at TIMESTAMP NOT NULL,
 retained_identity TEXT,
 retention_reason VARCHAR(1000),
 deleted_message_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
 photo_cleanup_complete BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE privacy_file_cleanup (
 patient_id BIGINT PRIMARY KEY REFERENCES account_closures(patient_id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
