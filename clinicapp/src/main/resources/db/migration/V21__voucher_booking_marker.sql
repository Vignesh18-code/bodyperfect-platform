ALTER TABLE appointments ADD COLUMN gift_voucher_booking BOOLEAN NOT NULL DEFAULT FALSE;
-- Existing collection bookings used this exact predefined note. Do not infer a
-- voucher booking from the account-level claim flag or unrelated free text.
UPDATE appointments SET gift_voucher_booking = TRUE
WHERE note = 'I would like to collect the AED 1,000 gift voucher.';
