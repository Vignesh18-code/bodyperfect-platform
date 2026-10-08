# Railway authentication email delivery

The API supports Resend over HTTPS, retaining the encrypted transactional mail outbox.
No SMTP connection is used when MAIL_PROVIDER is resend. The API key stays server-side.

In the backend service Variables, configure:

```text
MAIL_PROVIDER=resend
MAIL_FROM=BodyPerfect <noreply@zylinq.com>
RESEND_API_KEY=<set privately in Railway>
```

Keep SPRING_PROFILES_ACTIVE=prod, the database reference variables, JWT_SECRET,
APP_SECRETS_ENCRYPTION_KEY and the five policy settings. SMTP username/password are
not required in Resend mode. Do not use a new encryption key on each deployment.
The sending domain must be verified in Resend. Its receiving feature is not required;
preserve the main domain's Hostinger MX records.

Deploy the GitHub main branch, then check startup and /actuator/health. With a test
account you control, request an OTP, confirm delivery in both Resend and the inbox,
and use it in the app. Check password-reset delivery too. Never paste keys or OTPs
into logs or support messages. Provider acceptance does not prove inbox delivery.

Resend requests use a stable idempotency key for each encrypted outbox entry, a
5-second connection timeout and 10-second response timeout. Provider failures stop
the current batch; the existing bounded retries and five-minute expiry still apply.
Resend documents a 24-hour idempotency window, longer than this queue's lifetime.
SMTP remains the default for local Mailpit. Multiple workers use SKIP LOCKED;
provider account rate limits still apply across all services using that account.

Validation: mocked HTTPS requests cover retries, stable/distinct idempotency keys,
acknowledgement validation, configuration errors and SMTP fallback. Real Railway
startup and delivery require live verification after the settings are applied.

References:
- https://resend.com/docs/api-reference/emails/send-email
- https://resend.com/docs/dashboard/emails/idempotency-keys

Verified locally on 2026-10-08: backend suite 105 tests, 101 passed and four optional
AI tests skipped; production-profile packaged application reached health UP with
Resend selected and no SMTP credentials. Synthetic API key, worker disabled; no
live provider delivery was claimed or attempted in this check.
