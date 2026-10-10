# Launch progress — 10 October 2026

## Completed this run

- Three new administrator-bootstrap regression tests passed: first-admin creation with an encoded password; missing-secret rejection; existing-admin restart without changing credentials. Repeated startup now skips bootstrap rather than terminating the backend. Bootstrap must still be disabled and its password removed after first setup; run initial setup as a single instance.
- Fixed dashboard Nginx upstream Host routing for Railway. Built the actual Docker image and exercised it on loopback: page 200, proxied CSRF 200, anonymous staff endpoint 401. Production dashboard Origin must also be added to backend CORS_ALLOWED_ORIGINS.
- Production Spring profile launched on loopback against a new isolated PostgreSQL database, with email redirected to a local Mailpit inbox. Created synthetic administrator, clinician and patient accounts. No live patient records were touched.
- Real HTTP flow passed: administrator MFA and cookie login; clinician invitation and patient creation; emailed-code password setup; clinician MFA and patient login; voucher booking visible in staff appointment API and persisted patient claim; private report publication, exact-byte owner download, anonymous denial, withdrawal and empty list. This tests service integration, not the native file-save dialog or PDF rendering.
- Android debug APK built against the hosted HTTPS API. Artifact metadata: com.bodyperfect.clinicapp, version 1.0.1 (3), min SDK 24, target SDK 36.
- Owner confirmed first Play upload. A private upload key was created in ignored .local/android-signing, with ignored android/key.properties. Preserve secure backups of both. No secrets are in this report or source control.
- Existing GitHub verification run for bce9901 was successful.

## Access and remaining acceptance

- Owner supplied the production administrator email privately. Hosted account creation has not happened in this run.
- Railway CLI is authenticated to a different account which cannot see generous-purpose. Owner must sign into the correct Railway account before hosted administrator provisioning, dashboard service creation, variables, backups and deployment verification can proceed.
- Play Console access/account verification and any required closed testing are not established. A first AAB does not mean public release approval.
- Need physical Android release testing, native report Save/Share, actual maps/call handling, live AI quality/memory, hosted staff-to-patient round trips, backup restoration and final policy/deletion operational checks.
- No patient/staff passwords, signing passwords or API tokens should be added to GitHub or chat.

## Reusable local smoke test

scripts/smoke-local-workflows.py --accounts PATH_TO_PRIVATE_JSON is limited to loopback API 18080 and Mailpit 18025. Use a fresh disposable database with the production profile, a bootstrapped synthetic administrator, a stable test encryption key, MFA enabled and SMTP routed only to Mailpit. The JSON contains admin, clinician, patient and password. It creates synthetic users/bookings and withdraws its report; do not run against a reused database or proxy to production. The script intentionally cannot select a remote URL.

## Current official Android references

- Target API: https://support.google.com/googleplay/android-developer/answer/11926878
- 16 KB native-library support: https://developer.android.com/guide/practices/page-sizes
- Applicable personal-account closed testing (12 testers / 14 continuous days): https://support.google.com/googleplay/android-developer/answer/14151465

Two-day delivery should target a tested internal release; public publication depends on account eligibility and Google's review.

## Follow-up public-launch preparation

- GitHub run 38029338267 finished successfully for backend, dashboard and Flutter.
- Owner reports uploading the Android release to Play Console; the previous local artifact report predates that upload. Console release status remains unverified.
- Added per-service Railway Docker configuration, health checks and component watch paths; hosting config paths still need to be selected in the correct project.
- Added and executed read-only `scripts/check-hosted-release.py` against the live API. Health/readiness and six anonymous-access checks passed. Policy/contact and deletion-page contact checks failed because the live privacy email is missing its first letter. Retention text also has a missing opening letter. Details and exact correction are in `docs/RAILWAY_LAUNCH.md`.
- No live settings or customer records were changed. CLI access still points to an unrelated account; owner sign-in is required before deployment, backups, dashboard provisioning and authenticated acceptance can be completed.
