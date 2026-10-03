CREATE TABLE IF NOT EXISTS users (

    -- Identity
                                     id                      BIGSERIAL PRIMARY KEY,

    -- Personal Info
                                     full_name               VARCHAR(100)    NOT NULL,
    phone                   VARCHAR(15)     NOT NULL,
    email                   VARCHAR(150)    NOT NULL,
    preferred_treatment     VARCHAR(100),
    profile_image_url       VARCHAR(500),

    -- Security
    password                VARCHAR(255)    NOT NULL,
    role                    VARCHAR(20)     NOT NULL DEFAULT 'PATIENT',
    status                  VARCHAR(20)     NOT NULL DEFAULT 'PENDING',

    -- OTP
    otp                     VARCHAR(6),
    otp_expiry              TIMESTAMP,
    otp_attempts            INT             NOT NULL DEFAULT 0,
    otp_locked_until        TIMESTAMP,

    -- Points
    total_points            INT             NOT NULL DEFAULT 0,

    -- Login Security
    failed_login_attempts   INT             NOT NULL DEFAULT 0,
    locked_until            TIMESTAMP,
    last_login_at           TIMESTAMP,

    -- Soft Delete
    is_deleted              BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP
    );

-- Unique Constraints
ALTER TABLE users ADD CONSTRAINT uk_users_email UNIQUE (email);
ALTER TABLE users ADD CONSTRAINT uk_users_phone UNIQUE (phone);

-- Indexes for fast lookup
CREATE INDEX idx_users_email  ON users(email);
CREATE INDEX idx_users_phone  ON users(phone);
CREATE INDEX idx_users_status ON users(status);