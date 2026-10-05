# Backend hardening verification — 5 October 2026

Status: implementation and local verification complete for the changes below; NOT approved for live deployment or Play release.

## Delivered

- Public upload paths denied. Authenticated patients can fetch their own profile photo through `/api/user/profile/image`; no-store response headers.
- Password-confirmed account-deletion requests, deduplication, administrator review queue. Requests are not marked deleted or completed automatically. Actual fulfillment remains blocked on clinic retention decisions.
- In-app AI response reporting with ownership checks and administrator review; reports do not copy clinical conversation text into another store.
- Profile privacy/terms links from server configuration, plus `/account-deletion` public HTML contact instructions. No legal policy was invented.
- Staff TOTP enrollment/login, encrypted secrets, replay rejection, five-attempt lockout. Existing staff tokens revoked by migration V19. Generic login cannot bypass MFA when enabled. MFA is mandatory in production.
- Transactional encrypted email outbox, SMTP retries, expiry and payload removal. At-least-once delivery: process termination after SMTP acceptance can deliver the same code twice. Exhausted retries emit a warning without email/code values.
- Production configuration rejects missing privacy settings and encryption key. HTTPS policy URLs required.
- Separate production Compose, Caddy HTTPS, private database/API ports, durable database/photo/certificate volumes, non-root Java runtime.
- Operator-invoked encrypted database/photo backup script. The encrypted/off-host backup script has not been executed; a synthetic PostgreSQL dump/restore was verified separately.

## Evidence

Fresh PostgreSQL database `bp_continue_20261005_c`, separate from `ant_db`: Full suite: 100 backend tests discovered, 96 passed, 4 optional live-AI tests skipped. A subsequent targeted run passed all five workflow tests, including one added positive photo-upload/owner-only retrieval case; combined reports contain 101 tests, 97 passed and 4 skipped. All migrations V1–V19 applied. Tests include MFA enrollment/replay/lockout, authenticated encryption, privacy ownership/admin authorization, blocked public photos, and mail transaction rollback/retry cleanup.

Flutter analyzer: clean. Flutter: 39 tests passed. Dashboard: 6 tests passed and production bundle built. Both Compose files parsed with dummy configuration; production validation used a temporary empty env file. Git whitespace check passed.

Earlier rerun on reused test database encountered duplicate synthetic emails; the fresh full run passed. Docker Desktop was then started. Backend and dashboard images built, and an isolated Compose stack with the production Spring profile started successfully. HTTP checks passed for CSRF, MFA setup/login/replay, staff cookie/admin review access, the deletion page and anonymous photo denial. A recovery email arrived in the isolated Mailpit inbox. The Java process ran as UID 999. Uploads and encrypted authenticator verification survived API recreation; all 19 migrations and an enrolled authenticator restored into a separate synthetic database. Caddy validated the edge configuration. The temporary stack and its synthetic volumes were removed. Live DNS/TLS, production SMTP, spoofed-proxy-header behavior and the encrypted/off-host backup script remain unverified. No live database, server or existing clinic accounts were changed. The existing running preview still uses the original checkout, not these unified-repository changes.

## Required before deployment

1. Hosting provider/project/region, domains, DNS access and server credentials through a secure channel.
2. Approved legal clinic name, public privacy/support email, published privacy and terms URLs, retention rules and deletion fulfillment procedures. Finish the actual deletion/anonymization workflow against these rules; request intake alone is not a completed deletion system.
3. New server-only OpenAI key (replace the key shared previously), email provider credentials/sender verification, stable 32-byte encryption key, JWT/database secrets. Do not publish these in GitHub or chat.
4. Run Docker images and staging smoke tests, including browser MFA/CSRF, patient login, appointments/treatments, private images, AI reporting, email and reconnect/restart cases.
5. Configure off-host encrypted backups and monitoring; prove a restore into an isolated stack. Define MFA recovery identity checks and an audited operator procedure; no self-service recovery is implemented.
6. Complete Play policy/Data Safety/health declarations, signed AAB and 16-KB compatibility checks, review access and any applicable closed-testing requirement. No approval or production-readiness guarantee is implied by unit/integration tests.
