# Production deployment runbook

Do not deploy until the release blockers in `../docs/releases/BACKEND_HARDENING_2026-10-05.md` are resolved. Images and a synthetic local stack were tested, and the Caddy configuration validated. This has not been deployed to a production host.

## Configuration and startup

Use `compose.production.yaml` for hosting. `compose.yaml` is local only and includes Mailpit.

Copy `.env.example` to `.env` in this directory on the host, restrict permissions to 0600, and fill in real values. Never commit the completed file. Generate separate JWT/database secrets; generate `APP_SECRETS_ENCRYPTION_KEY` with `openssl rand -base64 32`. Preserve that key in a secret manager and a separately secured recovery location: changing it invalidates stored authenticator secrets and queued mail. Set policy/contact/legal/retention settings to approved values. Production refuses incomplete policy configuration.

Set SMTP provider host/port/credentials and `APP_MAIL_FROM` to the verified sender. For AI set `APP_AI_ENABLED=true`, `OPENAI_API_KEY` to a freshly rotated server-only key, and `OPENAI_MODEL` to the verified model. Real sender/domain delivery must be tested before admitting users.

The bootstrap operator settings are `APP_BOOTSTRAP_ENABLED=true` and `BOOTSTRAP_ADMIN_*` for initial setup only. Disable bootstrap and remove its password after the administrator enrolls an authenticator. Preserve the TOTP setup key privately until enrollment succeeds. Returning staff use password plus a new six-digit authenticator code.

From the repository root, on a host with Docker Engine/Compose and DNS pointed to it:

```sh
docker compose --env-file infrastructure/.env -f infrastructure/compose.production.yaml config --quiet
docker compose --env-file infrastructure/.env -f infrastructure/compose.production.yaml up -d --build
```

Only ports 80/443 are published. Restrict SSH to administrators. Do not publish 5432 or 8080. Volumes survive container replacement; never run `down -v` on production. Migration V19 signs existing staff out. Take a verified backup before any migration. Rollback across schema changes requires a tested compatible release or restoring a backup, not blindly deploying an older image.

## Proxy boundary

Caddy must be the first public proxy. It removes incoming `Forwarded`; its reverse proxy replaces untrusted incoming X-Forwarded headers. The backend trusts forwarded headers only in this private Compose topology so rate limiting can use the client address. Do not add a CDN/load balancer or expose backend ports without revalidating that trust boundary and spoofed-header tests. See [Caddy reverse proxy documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).

## Backup and restore

Install `age` on the operator host. Store the age private identity off-host. With an approved maintenance window, from repository root:

```sh
AGE_RECIPIENT=your_age_public_recipient BACKUP_DIR=/secure/backups ./scripts/backup-production.sh --maintenance
```

The script stops API writes, streams a PostgreSQL custom-format dump and uploaded files through encryption, writes COMPLETE only after success, then restarts the API. It does not schedule backups, transfer them off-host, or copy secrets. Retain the stable application encryption key separately. Configure scheduling and retention only after the clinic approves the required periods.

Before launch, decrypt a backup to a secured temporary directory and restore with `pg_restore --no-owner` into a NEW isolated database. Restore uploads to a NEW isolated volume, preserve ownership for the runtime clinic user, use the matching application encryption key, and disable outbound email/AI/bootstrap in that restore environment. Verify row counts, representative treatment/appointment records, private photo access and authenticator decryption. Never rehearse a restore over live data. Record restore time and recovery point, then securely remove temporary decrypted files. A synthetic local PostgreSQL restore passed. The complete encrypted/off-host database-and-upload recovery drill is still required.

## Release checks

Verify HTTPS, secure staff cookies and CSRF, patient login/refresh, staff MFA, authorization across two distinct patients, appointments/treatments, reporting and deletion request review. Test expired codes, SMTP failure/retry and instance restart. Exercise rate limiting from separate client addresses and spoofed forwarding headers. Verify the external deletion page and policy links are publicly reachable without login. Record image digests for the tested release and monitor error/latency, database capacity, SMTP exhaustion warnings and backup age.

Updating GitHub does not automatically deploy. Pull the reviewed commit on staging, run checks, back up, and run Compose again. Automated production rollout has not been configured.
