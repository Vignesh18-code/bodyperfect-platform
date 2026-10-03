-- Templates contain human-authored content only. Published versions are immutable in the API.
CREATE TABLE clinical_templates (
 id BIGSERIAL PRIMARY KEY,
 branch VARCHAR(30) NOT NULL,
 family_id UUID NOT NULL,
 revision INTEGER NOT NULL CHECK(revision > 0),
 name VARCHAR(150) NOT NULL,
 treatment_type VARCHAR(200) NOT NULL,
 instructions TEXT NOT NULL,
 planned_sessions INTEGER NOT NULL CHECK(planned_sessions BETWEEN 1 AND 200),
 state VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK(state IN ('DRAFT','PUBLISHED','RETIRED')),
 authored_by BIGINT NOT NULL REFERENCES users(id),
 approved_by BIGINT REFERENCES users(id),
 approved_at TIMESTAMPTZ,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(family_id,revision)
);
ALTER TABLE treatment_protocols ADD COLUMN branch VARCHAR(30);
ALTER TABLE treatment_protocols ADD COLUMN template_version_id BIGINT REFERENCES clinical_templates(id);
ALTER TABLE treatment_protocols ADD COLUMN approved_by BIGINT REFERENCES users(id);
ALTER TABLE treatment_protocols ADD COLUMN approved_at TIMESTAMPTZ;
ALTER TABLE treatment_protocols ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
CREATE INDEX idx_protocol_branch_patient ON treatment_protocols(branch,user_id,created_at DESC);
-- Legacy records are deliberately not assigned to a guessed branch.
ALTER TABLE appointments ALTER COLUMN status SET DEFAULT 'PENDING';
CREATE TABLE clinical_plan_events (
 id BIGSERIAL PRIMARY KEY,
 protocol_id BIGINT NOT NULL REFERENCES treatment_protocols(id),
 actor_id BIGINT NOT NULL REFERENCES users(id),
 status VARCHAR(20) NOT NULL,
 reason TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
