CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE TABLE clinic_services (
 id BIGSERIAL PRIMARY KEY,
 name VARCHAR(120) NOT NULL,
 duration_minutes INTEGER NOT NULL CHECK(duration_minutes BETWEEN 5 AND 480),
 active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE clinic_resources (
 id BIGSERIAL PRIMARY KEY,
 branch VARCHAR(30) NOT NULL CHECK(branch IN ('BURJUMAN','MARINA')),
 name VARCHAR(120) NOT NULL,
 timezone VARCHAR(80) NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE(id,branch)
);
CREATE TABLE resource_hours (
 resource_id BIGINT NOT NULL REFERENCES clinic_resources(id),
 weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7),
 opens TIME NOT NULL,
 closes TIME NOT NULL,
 CHECK(closes>opens),
 PRIMARY KEY(resource_id,weekday)
);
CREATE TABLE resource_blocks (
 id BIGSERIAL PRIMARY KEY,
 resource_id BIGINT NOT NULL REFERENCES clinic_resources(id),
 starts_at TIMESTAMPTZ NOT NULL,
 ends_at TIMESTAMPTZ NOT NULL,
 reason VARCHAR(200) NOT NULL,
 CHECK(ends_at>starts_at)
);
ALTER TABLE appointments ADD COLUMN resource_id BIGINT;
ALTER TABLE appointments ADD COLUMN service_id BIGINT REFERENCES clinic_services(id);
ALTER TABLE appointments ADD COLUMN starts_at TIMESTAMPTZ;
ALTER TABLE appointments ADD COLUMN ends_at TIMESTAMPTZ;
ALTER TABLE appointments ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE appointments ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'MOBILE';
ALTER TABLE appointments ADD CONSTRAINT fk_appointment_resource_branch FOREIGN KEY(resource_id,branch) REFERENCES clinic_resources(id,branch);
ALTER TABLE appointments ADD CONSTRAINT ck_appointment_interval CHECK (
 (resource_id IS NULL AND starts_at IS NULL AND ends_at IS NULL) OR
 (resource_id IS NOT NULL AND service_id IS NOT NULL AND starts_at IS NOT NULL AND ends_at IS NOT NULL AND ends_at>starts_at));
ALTER TABLE appointments ADD CONSTRAINT no_resource_overlap EXCLUDE USING gist
 (resource_id WITH =, tstzrange(starts_at,ends_at,'[)') WITH &&)
 WHERE (resource_id IS NOT NULL AND is_deleted=FALSE AND status IN ('PENDING','CONFIRMED','CHECKED_IN','IN_CONSULTATION'));
CREATE INDEX idx_appointments_branch_start ON appointments(branch,appointment_date,appointment_time) WHERE is_deleted=FALSE;
CREATE TABLE appointment_events (
 id BIGSERIAL PRIMARY KEY,
 appointment_id BIGINT NOT NULL REFERENCES appointments(id),
 actor_id BIGINT NOT NULL REFERENCES users(id),
 from_status VARCHAR(20),
 to_status VARCHAR(20) NOT NULL,
 old_start TIMESTAMPTZ,
 new_start TIMESTAMPTZ,
 reason VARCHAR(500),
 occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE appointment_idempotency (
 actor_id BIGINT NOT NULL REFERENCES users(id),
 operation VARCHAR(40) NOT NULL,
 key VARCHAR(100) NOT NULL,
 request_hash VARCHAR(64) NOT NULL,
 appointment_id BIGINT NOT NULL REFERENCES appointments(id),
 response_json TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(actor_id,operation,key)
);
