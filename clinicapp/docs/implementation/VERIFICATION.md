# Work unit 1 verification

25 September 2026. Synthetic data only; no deployment or live provider delivery.

| Check | Result | Evidence |
|---|---|---|
| Backend default H2 suite | 43 tests, zero failures/errors | [H2 log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/backend-h2.log) |
| Backend PostgreSQL 16 / Flyway / schema validation | 43 tests, zero failures/errors; V1–V9 applied | [PostgreSQL log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/backend-postgres.log) |
| Existing V8 data upgraded with V9 SQL | Account/status/password/777 points preserved; old code cleared | [Upgrade log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/migration-upgrade.log) |
| Backend package | PASS | [Package log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/backend-package.log) |
| Flutter analysis | PASS, no issues | [Analysis log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/flutter-analyze.log) |
| Android release APK | PASS, 69.1MB; local/default API configuration, not a deployment artifact | [Build log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/flutter-release.log) |
| Pure Dart session coordination | PASS: 20 concurrent calls share refresh; late 401 does not rotate; transient/invalid failures differ; exception recovery | [Check log](/Users/vignesh/.codex/visualizations/2026/09/25/01a0d85a-e2cf-7561-9eba-1ea358f3faf7/implementation/session-refresh.log) |
| Native Flutter widget/iOS checks | BLOCKED: objective_c build hook / unaccepted Xcode license and setup | Existing audit evidence; no mobile-device acceptance claimed |
| Hosted CI | NOT RUN; workflow definition added | Local PostgreSQL runner verified |
| Production load, restore, dashboard, staff/clinical UAT | NOT VERIFIED / NOT IMPLEMENTED in this work unit | Remaining approved plan |

The pure Dart check was copied with its production session_refresh.dart dependency into an isolated dependency-free temporary directory and run with the installed Dart SDK. This avoids unrelated native plugin hooks; it does not validate Flutter secure-storage plugins or UI behavior. Sources: ant/tool/session_refresh_check.dart and ant/lib/services/session_refresh.dart.

Regression coverage includes cross-purpose/replayed/expired OTPs, blocked/deleted accounts, registration preservation, pending password proof, single verification award under concurrency, password reset across sessions, refresh rotation/replay/concurrency, device/all-device logout, malformed refresh responses, protocol/session PostgreSQL timestamps, spoofed forwarding headers and eight competing patient bookings.

No credentials were rotated at their providers. No source changes were committed or pushed. Existing user changes were preserved; only approved implementation files were edited. V9 rollout requires a coordinated backend/mobile transition and re-authentication, as described in PROGRESS.md.


## Work unit 2 — 25 September 2026

- PostgreSQL 16: **58 tests passed, zero failures/errors/skips**, applying V1–V12 to a fresh disposable database. Evidence: `evidence/postgres-58-tests.log`. Includes 100 competing reservations with one winner; direct SQL overlap rejection; idempotent replay; request-to-reservation conversion; branch/clinical authorization; template draft/publish and immutable plan snapshots; optimistic versions and premature completion rejection.
- Default H2/package: 58 discovered, 15 PostgreSQL-specific tests skipped; 43 executed successfully. Evidence: `evidence/package-h2.log`. Later additive resourceId response field was compiled and packaged successfully.
- Dashboard: 5 Node API tests pass; production bundle succeeds. Tests cover 50 simultaneous unauthorized requests sharing refresh, CSRF headers, renewed CSRF challenges, error request IDs, and query encoding. Browser test found/fixed the stale-CSRF issue; synthetic patient creation then succeeded visibly.
- Browser: local administrator sign-in, real zero-count overview, patient directory and create, sign-out, clinician sign-in, clinician-only navigation, and synthetic template draft save verified. Desktop screenshots inspected. No comprehensive responsive, screen-reader, or full booking/clinical UAT is claimed.
- Flutter analyzer: no issues after appointment-state compatibility changes (`evidence/flutter-analyze.log`). Previous Android build remains earlier evidence; no updated device build is claimed. Native widget/iOS hooks still require the user's Xcode setup/license.
- Compose: `docker compose config --quiet` passed with synthetic environment substitutions. Docker Engine socket unavailable, so images/containers were not executed. Production image digests, non-root hardening, TLS and provider setup remain pending.
- `git diff --check` passed for backend and Flutter. Existing unrelated user changes preserved.
- Local browser preview: Vite 127.0.0.1:5173 -> API 127.0.0.1:58192 -> disposable PostgreSQL 127.0.0.1:55439. Mail points to an unused local port; no real mail was sent. Preview fixture credentials must never be reused outside this disposable database.


## Work unit 3 — 26 September 2026

- PostgreSQL: **62 passed, zero failures/errors/skips**; V1–V15 migrations. `evidence/core-postgres-62.log`.
- Invitation tests cover setup-purpose separation, activation with a chosen password, no reward inflation/replay, and blocked invitations. Session tests cover permission, idempotent link, reschedule synchronization, clinical transitions, completion and plan guards. Follow-up tests cover branch access, eligible assignees and stale resolution.
- Live localhost API and SMTP smoke: all six workflow groups passed. `evidence/local-smoke.log`.
- Dashboard: **6 passed**, build passed. `evidence/dashboard-tests.log`, `evidence/dashboard-build.log`.
- Flutter analyzer passed; JavaScript web target compiled, served and visually inspected. `evidence/local-flutter-analyze.log`, `evidence/patient-web-build.log`. Wasm/plugin warnings are not a failed JavaScript build; Wasm/iOS/device support remains unverified.
- Browser verified patient sign-in, persisted session after reload, active template instructions, progress and linked upcoming session; clinician workspace renders approved template data.
- Local API health is UP, email sink receives messages, and patient/staff static pages respond. Local services bind loopback. Docker remains stopped; no container or production deployment claim.

## 26 September 2026 — AI / clinic-team support

- Fresh PostgreSQL database `bodyperfect_support3`: V1–V16 applied; **74 tests passed, zero failures/errors/skips**. Includes 10 SupportTests and 2 OpenAiGatewayTests. Provider is mocked: no external AI request or real medical data sent.
- Consent and disabled AI, explicit approved own-patient context excluding auth/contact/internal notes/unapproved/other-patient records, provider failure, per-patient budgets, old UUID deduplication and interrupted-request recovery verified.
- Support ownership/branch authorization, revoked membership, validation, CSRF, pagination, rate limit, UUID deduplication, optimistic conflicts, staff notification and audit verified.
- Dashboard: 6 existing transport tests pass; production bundle builds. Flutter: analyzer clean; JavaScript web bundle builds (WASM dry-run warnings remain).
- CUA local UI: synthetic BP-7 message appeared in Patient support, clinician claimed it, replied, patient displayed the reply, clinician resolved. No real customer communication performed.
- API restarted with final package on loopback58192. Provider key and model absent; AI unavailable status shown correctly. `AI_SUPPORT_SETUP.md` describes server-only configuration and remaining release gates. Not publicly deployed; live OpenAI and native-device checks remain outstanding.
- Evidence: `evidence/support-postgres-74-summary.log`, `support-flutter-analyze.log`, `support-web-build.log`, `support-dashboard-build.log`.
