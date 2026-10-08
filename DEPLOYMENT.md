# Production Deployment

## Backend environment variables

Run the backend with the `prod` profile and set these variables in the hosting provider:

```bash
SPRING_PROFILES_ACTIVE=prod
PORT=8080
DATABASE_URL=jdbc:postgresql://HOST:5432/DB_NAME
DATABASE_USERNAME=DB_USER
DATABASE_PASSWORD=DB_PASSWORD
JWT_SECRET=generate-a-new-random-secret-at-least-32-bytes-long
MAIL_USERNAME=your-smtp-user
MAIL_PASSWORD=your-smtp-password
CORS_ALLOWED_ORIGINS=https://bodyperfect.ae,https://www.bodyperfect.ae,https://admin.bodyperfect.ae
UPLOAD_DIR=/var/app/uploads
AUTH_RATE_LIMIT_MAX_ATTEMPTS=20
AUTH_RATE_LIMIT_WINDOW_SECONDS=60
DB_POOL_MAX_SIZE=30
DB_POOL_MIN_IDLE=5
```

Rotate any credentials that were previously committed before going live.

## Backend health check

Use this endpoint for load balancer and uptime checks:

```text
GET /actuator/health
```

## Flutter release API URL

Build mobile/web releases with the hosted API URL:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.bodyperfect.ae
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.bodyperfect.ae
flutter build ios --release --dart-define=API_BASE_URL=https://api.bodyperfect.ae
```

Android release builds now require a real signing key in `ant/android/key.properties`.
Create the key file locally or in CI; do not commit it.

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=/absolute/path/to/upload-keystore.jks
```

## Scale notes for 1M installs

Use managed PostgreSQL with automated backups, connection pooling, and read replicas when traffic grows. Run the backend behind a load balancer with at least two instances, keep uploaded media in object storage such as S3-compatible storage, and send emails through a production provider with rate limits suitable for OTP traffic.

## Production launch checklist

- Enforce HTTPS only at the load balancer or reverse proxy.
- Redirect all HTTP traffic to HTTPS.
- Keep `CORS_ALLOWED_ORIGINS` limited to production domains only.
- Use a random `JWT_SECRET` of at least 32 bytes; 64+ bytes is preferred.
- Rotate any secret that was ever committed or shared.
- Put the backend behind a reverse proxy/load balancer such as Nginx, ALB, Cloudflare, or equivalent.
- Configure gateway/load-balancer rate limits in addition to the app-level auth rate limit.
- Use managed PostgreSQL with automated daily backups and point-in-time recovery.
- Enable database connection pooling; start with `DB_POOL_MAX_SIZE=30` per backend instance and tune from metrics.
- Keep uploads in object storage for multi-instance deployments; local disk is only acceptable for a single-node MVP.
- Configure log rotation and centralized logs.
- Monitor p50/p95/p99 latency, error rate, JVM memory, CPU, DB connections, slow queries, disk, and email failures.
- Add uptime checks against `/actuator/health`.
- Add alerts for high 5xx rate, high 4xx spikes, DB pool exhaustion, JVM memory pressure, and failed health checks.
- Maintain a staging environment with production-like database size and config.
- Run k6 tests only against local/staging unless explicitly approved.
- Define a rollback plan: keep previous backend artifact/container, database migration rollback notes, and app store release rollback procedure.
- Run Flyway migrations in a controlled deployment step before shifting traffic.
- Use blue/green or rolling deploys with health checks for zero-downtime releases.
- Keep SMTP/API provider limits documented for OTP and password reset traffic.

## Reverse proxy notes

Forward these headers so rate limiting and logs can identify the real client:

```text
X-Forwarded-For
X-Forwarded-Proto
Host
```

Terminate TLS at the proxy/load balancer and allow backend traffic only from trusted private networks.

## Hosting handoff — 3 October 2026

Cloud deployment has not been performed. The owner chose one new private GitHub repository containing `ant`, `clinicapp`, `dashboard`, infrastructure and shared CI. Hosting account, region and domain remain undecided. Existing component repositories are preserved; `scripts/export-monorepo.py DESTINATION` exports current tracked and untracked source into a separate Git repository, excluding local secrets, generated output, uploads and nested Git directories. It refuses an existing destination. Its credential scan is a basic guard, not a complete security audit; review the proposed commit before publishing.

The root `.github/workflows/platform.yml` verifies all three components. GitHub should hold source code only, never the database or patient files. Deploy from a reviewed commit after CI passes, smoke-test staging, then promote the same release. Updates to API/dashboard can deploy from GitHub; native Flutter updates still need a signed app release. Work in the new checkout after migration to avoid divergent copies.

The dashboard container accepts server-only `API_UPSTREAM` (an origin without a trailing slash). Default `http://api:8080` preserves local Compose; hosted environments supply their private backend URL or public HTTPS API URL. Nginx renders only this variable, preserving request variables. Browser calls remain same-origin `/api` for staff cookies and CSRF. No database or OpenAI credentials belong in Vite variables.

### Database ownership and rollout

The active local database is PostgreSQL `ant_db` on the developer Mac. Provision a separate managed PostgreSQL 16 database for hosting, with `btree_gist` available, private access, provider-required TLS, automated backups and a verified restore. Keep staging separate from production. New deployments reuse the same database and upload storage; do not recreate or reset them on GitHub pushes. Flyway handles schema migrations; code rollback does not undo a database migration. Review migrations and backup before production changes.

Use a fresh database for synthetic staging acceptance. Moving existing accounts/records is a separate reviewed export/import decision; do not copy local test accounts or fixtures into production automatically. Bootstrap the first administrator once, then disable bootstrap and remove its password. Store secrets in the host secret manager, rotate the previously shared OpenAI key, and verify actual outbound SMTP delivery.

### Known limits before public patient launch

The existing Compose stack is local-only (Mailpit and insecure HTTP cookie settings). Public profile upload URLs still need private authorization; staff MFA and backup/restore acceptance remain outstanding. Confirm real clinic configuration, privacy/content approval and the provider region before real patient use. The next deploy can be restricted staging while these are completed. Local passing tests are not public launch acceptance.

Dashboard tests and bundle passed during this handoff. Container execution is not verified because Docker Engine is not running locally. No GitHub upload or cloud provisioning has occurred.

## Client PDF reports

Migration V22 adds `patient_reports`. Clinicians publish reviewed PDFs through **Patients → Open record → Client reports** in the dashboard. Only a clinician assigned to that branch can upload, download or withdraw reports for a branch-associated patient. The patient API always derives ownership from the authenticated account; no public file links are created.

Reports appear below the appointment card, including when the client has no upcoming appointment. An empty list takes no space. The app's Download button fetches the authenticated PDF and opens the platform save/share sheet (on iOS choose Save to Files). The dashboard downloads directly. Withdrawing removes the stored PDF and client access while retaining report metadata and audit events. Already downloaded copies cannot be recalled.

- PDF only, maximum 5 MiB, maximum 100 active reports per patient. Validation checks declared MIME type, PDF signature and EOF; this is not malware scanning. Only reviewed clinic PDFs should be published.
- PDF contents are encrypted using the existing `APP_SECRETS_ENCRYPTION_KEY` and stored in PostgreSQL, so no extra public storage bucket or upload volume is required for reports. Uploads refuse to run without a persistent key. Back up the database and keep this key securely recoverable; changing it without re-encryption makes existing reports unreadable.
- Sample report titles are confined to widget tests. No synthetic reports are inserted into client accounts.
- Deploy the backend migration before using the updated Flutter/dashboard clients. Verify upload, owner download and withdrawal with an authorized test account after deployment.
