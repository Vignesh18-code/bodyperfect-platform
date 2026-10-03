CREATE TABLE follow_up_tasks (
 id BIGSERIAL PRIMARY KEY,
 branch VARCHAR(30) NOT NULL CHECK(branch IN ('BURJUMAN','MARINA')),
 patient_id BIGINT NOT NULL REFERENCES users(id),
 assigned_to BIGINT NOT NULL REFERENCES users(id),
 created_by BIGINT NOT NULL REFERENCES users(id),
 title VARCHAR(200) NOT NULL,
 due_date DATE NOT NULL,
 state VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK(state IN ('OPEN','DONE','CANCELLED')),
 resolution VARCHAR(1000),
 version BIGINT NOT NULL DEFAULT 0,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 resolved_at TIMESTAMPTZ
);
CREATE INDEX idx_follow_up_branch_due ON follow_up_tasks(branch,state,due_date,id);
