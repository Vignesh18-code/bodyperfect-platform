ALTER TABLE assistant_exchanges ADD COLUMN sources JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE assistant_exchanges ADD COLUMN actions JSONB NOT NULL DEFAULT '[]'::jsonb;
CREATE TABLE assistant_preferences (
 patient_id BIGINT PRIMARY KEY REFERENCES users(id),
 memory_enabled BOOLEAN NOT NULL DEFAULT TRUE,
 note VARCHAR(1000) NOT NULL DEFAULT '',
 updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Keep the usage budget independent of deletable conversation history.
CREATE TABLE assistant_usage (
 patient_id BIGINT NOT NULL REFERENCES users(id),
 client_id UUID NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(patient_id,client_id)
);
INSERT INTO assistant_usage(patient_id,client_id,created_at)
 SELECT patient_id,client_id,created_at FROM assistant_exchanges;
CREATE INDEX idx_assistant_usage_time ON assistant_usage(patient_id,created_at);
CREATE INDEX idx_assistant_recall ON assistant_exchanges USING gin
 (to_tsvector('english',question || ' ' || coalesce(answer,''))) WHERE state='COMPLETED';
