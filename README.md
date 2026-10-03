# BodyPerfect platform

Unified source repository for the Flutter patient application, Spring Boot backend and staff dashboard. This snapshot was exported on 3 October 2026 without altering the original component repositories. Cloud deployment and GitHub publication are pending; this is not a declaration of production acceptance.

| Directory | Component | Runtime |
| --- | --- | --- |
| `ant` | Patient app | Flutter 3.38.6 |
| `clinicapp` | API, migrations, clinic knowledge | Java 21, Spring Boot, PostgreSQL 16 |
| `dashboard` | Staff dashboard | Node 22, React, Nginx |
| `infrastructure` | Local Compose environment | Docker |
| `.github/workflows` | Component tests and build checks | GitHub Actions |

See [deployment and database operations](DEPLOYMENT.md) and [AI support setup](AI_SUPPORT_SETUP.md). The Compose file is local-only and must not be exposed as production.

## Updates

Make changes in this checkout after repository migration. Push a branch, review its pull request, pass the platform CI checks, deploy to staging, smoke-test, then promote to production. The new repository contains current source, not the old component commit histories; those remain in their original repositories.

Backend/dashboard deployments can follow GitHub updates. Mobile UI changes need signed app releases. Database records and uploads live outside GitHub and must survive every code deployment. Do not reset databases as part of deployment. Configure secrets only in the hosting account; never commit local accounts, credentials, uploads, database dumps or signing keys.

## Verification

- Backend: Java 21, `cd clinicapp && mvn test`; PostgreSQL regression uses a separate disposable test database with `scripts/test-postgres.sh`.
- Dashboard: `cd dashboard && npm ci && npm test && npm run build`.
- Patient app: `cd ant && flutter pub get && flutter analyze && flutter test`.

The GitHub workflow checks these components. Container execution still needs verification with a running Docker Engine. Known public-launch gaps include private photo access, staff MFA, verified production email, backup/restore acceptance and final clinic configuration.
