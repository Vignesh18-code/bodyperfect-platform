-- A claim is recorded only after a successful voucher appointment request.
-- This is collection intent, not approval of a discount or payment credit.
ALTER TABLE users ADD COLUMN gift_voucher_claimed_at TIMESTAMP;
