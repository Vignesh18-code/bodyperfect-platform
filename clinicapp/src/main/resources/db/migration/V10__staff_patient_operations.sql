CREATE TABLE staff_memberships (
    user_id BIGINT NOT NULL REFERENCES users(id),
    branch VARCHAR(30) NOT NULL CHECK (branch IN ('BURJUMAN','MARINA')),
    staff_role VARCHAR(30) NOT NULL CHECK (staff_role IN ('RECEPTION','CLINICIAN','BRANCH_MANAGER')),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY(user_id, branch)
);
CREATE TABLE patient_branches (
    patient_id BIGINT NOT NULL REFERENCES users(id),
    branch VARCHAR(30) NOT NULL CHECK (branch IN ('BURJUMAN','MARINA')),
    PRIMARY KEY(patient_id, branch)
);
-- Existing appointment records establish an existing operational branch relationship.
INSERT INTO patient_branches(patient_id,branch)
SELECT DISTINCT user_id,branch FROM appointments;
CREATE TABLE audit_events (
    id BIGSERIAL PRIMARY KEY,
    actor_id BIGINT NOT NULL REFERENCES users(id),
    branch VARCHAR(30),
    action VARCHAR(80) NOT NULL,
    entity_type VARCHAR(40) NOT NULL,
    entity_id BIGINT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    request_id VARCHAR(80) NOT NULL
);
CREATE INDEX idx_audit_branch_time ON audit_events(branch, occurred_at DESC, id DESC);
CREATE INDEX idx_patient_branch ON patient_branches(branch,patient_id);
ALTER TABLE users ADD COLUMN profile_version BIGINT NOT NULL DEFAULT 0;
