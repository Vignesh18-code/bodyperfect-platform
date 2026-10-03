ALTER TABLE treatment_sessions ADD COLUMN appointment_id BIGINT REFERENCES appointments(id);
ALTER TABLE treatment_sessions ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX uq_session_appointment ON treatment_sessions(appointment_id) WHERE appointment_id IS NOT NULL;
