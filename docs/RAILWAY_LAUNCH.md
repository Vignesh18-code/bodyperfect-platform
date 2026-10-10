# BodyPerfect Railway launch

Use the unified GitHub repository `Vignesh18-code/bodyperfect-platform`, main branch. Do not recreate the database or signing key on updates.

## Service settings

| Setting | Existing API | New staff dashboard |
| --- | --- | --- |
| Root directory | `/clinicapp` | `/dashboard` |
| Config file path (repository absolute) | `/clinicapp/railway.json` | `/dashboard/railway.json` |
| Builder | Dockerfile | Dockerfile |
| Public target port | 8080 | 8080 |
| Health check | `/actuator/health` | `/` |
| Source | unified repository, main | same repository, main |

The checked-in config controls Docker builds, component watch paths, startup health checks and bounded restart attempts. Select the config file path explicitly: a monorepo root directory does not automatically set the config path. Enable Wait for CI on both services. Railway startup checks do not provide continuous uptime monitoring.

## Dashboard connection and administrator

Set server-only `API_UPSTREAM=https://bodyperfect-platform-production.up.railway.app` with no trailing slash. Generate its HTTPS domain and add that exact origin to the API's existing `CORS_ALLOWED_ORIGINS` list, preserving approved existing origins. Keep staff secure cookies and MFA enabled. Do not put secrets in Vite or Flutter variables.

Use the existing administrator if present. If none exists, bootstrap the privately supplied owner email once using `APP_BOOTSTRAP_ENABLED=true`, `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_NAME`, `BOOTSTRAP_ADMIN_PHONE` and a privately generated `BOOTSTRAP_ADMIN_PASSWORD` (14+ characters, at most 72 UTF-8 bytes). Use one API instance for first setup. Disable bootstrap and remove the password after verifying creation. The administrator enrolls MFA; invite a branch clinician for clinical workflows. Patient test logins are not dashboard staff logins.

## Existing live configuration corrections

Observed 10 October 2026: the public policies API returns `nfo@bodyperfect.ae`. Correct `PRIVACY_CONTACT_EMAIL` to the approved `info@bodyperfect.ae`. The current `RETENTION_NOTICE` begins `e keep`; correct its opening to `We keep` without inventing a retention period. The clinic still needs to approve a complete app-specific retention notice and policy. These are hosting-variable changes, not Flutter code changes.

## Storage and recovery before real patient use

Profile photos use `UPLOAD_DIR` filesystem storage. Confirm a persistent Railway volume covers this directory before accepting photos; container files alone do not survive replacement. Confirm the non-root clinic user can write the mounted path. Before adding a volume over an existing path, preserve any existing uploads so the mount does not hide them. Reports and staff MFA are encrypted in PostgreSQL using the stable `APP_SECRETS_ENCRYPTION_KEY`; never replace it during deployment.

Enable scheduled backups on the PostgreSQL volume and on the photo volume. Preserve encryption keys and the Android upload key separately in secure recoverable storage. Verify a restore in an isolated environment; do not restore over production to test it. `scripts/backup-production.sh` targets the separate Docker Compose stack and must not be treated as a Railway backup command. Verify service funding/usage alerts, provider region, monitoring and an available prior deployment for rollback. Database migrations are not undone by code rollback.

## Read-only post-deployment check

```sh
python3 scripts/check-hosted-release.py --api https://bodyperfect-platform-production.up.railway.app --contact-email info@bodyperfect.ae --dashboard https://YOUR-DASHBOARD-DOMAIN
```

Omit `--dashboard` to check only the API; the result explicitly leaves dashboard checks pending. The script performs GET requests, prints no tokens or response bodies, and exits nonzero for failed checks. It verifies transport/configuration and anonymous rejection; a 401 alone does not prove a protected route is deployed. It does not create accounts, send emails or certify policies.

Then use synthetic accounts to verify login/recovery, patient booking to clinician confirmation, treatment plan visibility, one-time voucher, private report download/withdrawal, AI continuity and clinic support reply. Verify on the signed Android release and complete Google Play declarations/reviewer access. A successful health check is not public-launch approval.

## Verified evidence and outstanding access

GitHub run 38029338267 passed backend, dashboard and Flutter checks. The signed Android bundle is version 1.0.1+3, package `com.bodyperfect.clinicapp`, API 36, targeting the existing HTTPS backend. The owner reports uploading it; Play release status is not independently verified.

The local Railway CLI is signed into an account that cannot see `generous-purpose`. Hosted dashboard provisioning, administrator creation, corrected variables, deployed revision, persistent volumes and backups remain unverified until the owner reconnects that account. Never perform these changes on unrelated Railway projects.

References: [Railway monorepos](https://docs.railway.com/deployments/monorepo), [configuration](https://docs.railway.com/config-as-code/reference), [health checks](https://docs.railway.com/deployments/healthchecks), [backups](https://docs.railway.com/volumes/backups).
