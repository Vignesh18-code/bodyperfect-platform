package com.vignesh.clinicapp.auth.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class SanitizationService {

    // ── Remove ALL dangerous characters ────────────────
    public String sanitize(String input) {
        if (input == null) {
            return null;
        }

        String original = input;

        // Step 1: Trim whitespace
        String cleaned = input.trim();

        // Step 2: Remove HTML tags
        cleaned = cleaned.replaceAll("<[^>]*>", "");
        /*
         * <script>alert('hack')</script>
         *  ↓
         * alert('hack')
         *
         * <b>bold</b>
         *  ↓
         * bold
         */

        // Step 3: Remove dangerous characters
        cleaned = cleaned.replaceAll("[<>\"'`;(){}\\[\\]\\\\]", "");
        /*
         * Removes: < > " ' ` ; ( ) { } [ ] \
         *
         * These characters are used in:
         * XSS attacks      → <script>, javascript:
         * SQL injection    → '; DROP TABLE users;
         * Command injection → `rm -rf /`
         */

        // Step 4: Remove javascript: and data: protocols
        cleaned = cleaned.replaceAll("(?i)javascript\\s*:", "");
        cleaned = cleaned.replaceAll("(?i)data\\s*:", "");
        /*
         * (?i) = case insensitive
         *
         * Blocks:
         * javascript:alert('hack')
         * JAVASCRIPT:alert('hack')
         * data:text/html,<script>...
         */

        // Step 5: Remove event handlers
        cleaned = cleaned.replaceAll("(?i)on\\w+\\s*=", "");
        /*
         * Blocks:
         * onerror=alert('hack')
         * onclick=stealData()
         * onload=malicious()
         */

        // Step 6: Remove multiple spaces
        cleaned = cleaned.replaceAll("\\s+", " ");

        // Log if input was modified
        if (!original.trim().equals(cleaned)) {
            log.warn("Input sanitized → original: [{}] cleaned: [{}]",
                    original, cleaned);
        }

        return cleaned;
    }

    // ── Sanitize email (special rules) ─────────────────
    public String sanitizeEmail(String email) {
        if (email == null) {
            return null;
        }

        // Only allow: letters, numbers, @ . _ + -
        String cleaned = email.trim().toLowerCase();
        cleaned = cleaned.replaceAll("[^a-z0-9@._+\\-]", "");
        /*
         * valid:   john.doe+test@gmail.com ✅
         * cleaned: <script>john@gmail.com  �� scriptjohngmail.com
         */

        return cleaned;
    }

    // ── Sanitize phone (only digits) ───────────────────
    public String sanitizePhone(String phone) {
        if (phone == null) {
            return null;
        }

        // Only allow: digits and +
        String cleaned = phone.trim();
        cleaned = cleaned.replaceAll("[^0-9+]", "");
        /*
         * valid:   +919876543210 ✅
         * cleaned: +91-9876-5432  → +919876543210
         * cleaned: abc9876543210  → 9876543210
         */

        return cleaned;
    }
}