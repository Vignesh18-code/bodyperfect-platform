CREATE TABLE support_threads (
 id BIGSERIAL PRIMARY KEY,
 patient_id BIGINT NOT NULL REFERENCES users(id),
 branch VARCHAR(30) NOT NULL CHECK(branch IN ('BURJUMAN','MARINA')),
 state VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK(state IN ('OPEN','RESOLVED')),
 assigned_to BIGINT REFERENCES users(id),
 version BIGINT NOT NULL DEFAULT 0,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(patient_id,branch)
);
CREATE INDEX idx_support_inbox ON support_threads(branch,state,updated_at DESC,id DESC);
CREATE TABLE support_messages (
 id BIGSERIAL PRIMARY KEY,
 thread_id BIGINT NOT NULL REFERENCES support_threads(id),
 sender_id BIGINT NOT NULL REFERENCES users(id),
 sender_role VARCHAR(20) NOT NULL CHECK(sender_role IN ('PATIENT','STAFF')),
 client_id UUID NOT NULL,
 body VARCHAR(4000) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(thread_id,sender_id,client_id)
);
CREATE INDEX idx_support_messages_thread ON support_messages(thread_id,id);
CREATE TABLE assistant_exchanges (
 id BIGSERIAL PRIMARY KEY,
 patient_id BIGINT NOT NULL REFERENCES users(id),
 client_id UUID NOT NULL,
 question VARCHAR(2000) NOT NULL,
 answer TEXT,
 state VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','COMPLETED','FAILED')),
 model VARCHAR(100),
 consent_version VARCHAR(30) NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 finished_at TIMESTAMPTZ,
 UNIQUE(patient_id,client_id)
);
CREATE INDEX idx_assistant_patient_time ON assistant_exchanges(patient_id,created_at DESC);
