ALTER TABLE users ADD COLUMN setup_required BOOLEAN NOT NULL DEFAULT FALSE;
-- Pre-existing pending accounts are not reclassified automatically.
