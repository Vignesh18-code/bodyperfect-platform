CREATE TABLE patient_reports (
    id BIGSERIAL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES users(id),
    branch VARCHAR(30) NOT NULL CHECK (branch IN ('MARINA','BURJUMAN')),
    title VARCHAR(150) NOT NULL,
    report_date DATE NOT NULL,
    size_bytes INTEGER NOT NULL CHECK (size_bytes BETWEEN 1 AND 5242880),
    encrypted_pdf TEXT,
    uploaded_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    withdrawn_at TIMESTAMPTZ,
    CHECK ((withdrawn_at IS NULL) = (encrypted_pdf IS NOT NULL))
);
CREATE INDEX idx_patient_reports_visible ON patient_reports(patient_id, report_date DESC, id DESC) WHERE withdrawn_at IS NULL;
