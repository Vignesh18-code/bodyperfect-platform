-- ============================================================
-- Treatment Protocol & Sessions
-- ============================================================

CREATE TABLE treatment_protocols (
    id              BIGSERIAL       PRIMARY KEY,
    user_id         BIGINT          NOT NULL REFERENCES users(id),

    protocol_name   VARCHAR(150)    NOT NULL,
    treatment_type  VARCHAR(200),
    status          VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',

    weight_kg       DECIMAL(5,1),
    height_cm       DECIMAL(5,1),
    bmi             DECIMAL(4,1),
    goal_weight_kg  DECIMAL(5,1),

    total_sessions  INTEGER         NOT NULL DEFAULT 0,
    instructions    TEXT,

    start_date      DATE,
    end_date        DATE,
    notes           TEXT,

    is_deleted      BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_protocol_user     ON treatment_protocols(user_id);
CREATE INDEX idx_protocol_status   ON treatment_protocols(status);

-- ────────────────────────────────────────────────────────────

CREATE TABLE treatment_sessions (
    id                BIGSERIAL       PRIMARY KEY,
    protocol_id       BIGINT          NOT NULL REFERENCES treatment_protocols(id),
    user_id           BIGINT          NOT NULL REFERENCES users(id),

    session_number    INTEGER         NOT NULL,
    session_name      VARCHAR(200)    NOT NULL,

    session_date      DATE            NOT NULL,
    session_time      TIME            NOT NULL,
    duration_minutes  INTEGER         NOT NULL DEFAULT 30,

    status            VARCHAR(20)     NOT NULL DEFAULT 'SCHEDULED',

    notes             TEXT,
    is_deleted        BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_session_protocol  ON treatment_sessions(protocol_id);
CREATE INDEX idx_session_user      ON treatment_sessions(user_id);
CREATE INDEX idx_session_date      ON treatment_sessions(session_date);
CREATE INDEX idx_session_status    ON treatment_sessions(status);
CREATE INDEX idx_session_user_date ON treatment_sessions(user_id, session_date);
