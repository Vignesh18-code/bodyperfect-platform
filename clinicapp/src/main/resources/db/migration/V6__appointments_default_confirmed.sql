-- Auto-confirm appointments (no admin approval flow).
-- The clinic team coordinates manually with the client after booking.

-- 1. Change DB default for new rows
ALTER TABLE appointments ALTER COLUMN status SET DEFAULT 'CONFIRMED';

-- 2. Promote any leftover PENDING test data to CONFIRMED for consistency
UPDATE appointments
SET status = 'CONFIRMED', updated_at = CURRENT_TIMESTAMP
WHERE status = 'PENDING' AND is_deleted = FALSE;
