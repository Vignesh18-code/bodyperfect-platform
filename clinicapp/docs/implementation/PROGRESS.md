# Approved implementation progress

Approval: user authorized the expanded core-operations plan on 25 September 2026.
Scope: Flutter patient app, Spring Boot/PostgreSQL, new staff dashboard; CRM/payments/report delivery deferred.
The full approved plan remains in the audit artifacts. This journal records completed work and remaining gates; it is not a production-readiness certificate.

## Work unit 1: identity, integrity and client compatibility

Implemented:

- Purpose-bound BCrypt-hashed OTPs, five-attempt budget preserved across resend, atomic challenge consumption under a user row lock. Only pending, non-deleted accounts can verify; blocked users cannot reactivate. Re-registration cannot replace pending credentials. Pending login must prove the password before triggering email.
- Persistent hashed refresh-token records, rotation, absolute family expiry and reuse detection. Replay revokes that device family. Password reset and logout-all revoke every family and advance a token version. Access requests check the current account, role, version and live session family.
- Authenticated logout and logout-all endpoints. Public refresh errors do not disclose parser internals. Registration/reset passwords now respect the existing ASCII BCrypt 72-byte limit.
- V9 migration creates refresh sessions and invalidates old untyped codes. Existing pre-V9 JWTs are intentionally rejected; users must sign in again.
- Treatment protocol/session insert timestamps now match PostgreSQL NOT NULL constraints.
- Existing one-future-appointment policy is serialized under a PostgreSQL user-row lock for create and reschedule. Terminal records cannot be rescheduled and do not block a new booking. Past-date validation exists at the service boundary.
- Removed the scheduler operation that auto-completed and soft-deleted appointments at their start time. History is retained; staff attendance/completion is still future work.
- Rate limiter ignores arbitrary X-Forwarded-For and includes registration. Production forwarding is disabled until a trusted edge is explicitly configured. Per-account/distributed limiting remains future work.
- Flutter shares a single refresh operation, saves both rotated tokens as one secure-storage value, ignores late 401s for old access tokens, and preserves credentials on connectivity/server failures. Storage writes are serialized with a generation guard against logout races. Logout attempts backend revocation before local cleanup. Offline local logout cannot guarantee remote revocation.
- Multipart avatar requests send the matching image media type. Server-side decoding and private storage remain open.
- Removed the forced two-second startup wait. This is not a full startup/motion redesign.
- Externalized current DB/SMTP/JWT credentials; existing unrelated configuration preserved. Added explicit SMTP read/write timeouts, graceful shutdown settings, and disabled automatic production Flyway baselining.
- Added PostgreSQL regression runner and a backend CI workflow definition. The local commands are verified; hosted CI has not run.

## Deployment compatibility and operational cautions

Do not deploy this work unit alone as a production-ready platform. V9 intentionally expires existing authentication sessions/codes. Ship the updated mobile refresh behavior with the backend and plan a maintenance/re-authentication window; older clients only save the access token and cannot sustain rotating refresh sessions. Mixed old/new backend replicas are not a supported rolling transition because old replicas do not enforce these controls. Existing secret exposure requires owner-managed credential rotation; replacing literals does not revoke credentials at providers. Configure DATABASE_PASSWORD, JWT_SECRET, MAIL_USERNAME and MAIL_PASSWORD before normal startup. No real database or email provider was used here.

Strict refresh replay detection can invalidate a family after a response is lost; the client must then sign in again. This favors security over a replay grace period. Expired refresh records need a retention/purge policy and monitoring before production scale. Database validation must run before rollout; runtime/migration DB roles and production access remain unverified.

The booking fix enforces the pre-existing patient-level rule across current service paths. It is not staff/room capacity management, a reservation exclusion constraint or an idempotency implementation. Future staff write routes must share the same transaction policy until the full reservation engine replaces it.

## Remaining approved work after work unit 1 (historical)

1. Staff/branch membership, authorization matrix and safe administrator bootstrap; patient directory/360.
2. Resource availability, full appointment transitions, idempotency, staff calendar and database reservation invariants.
3. Clinician-approved versioned templates/plans/sessions and follow-up tasks; clinical rules require owner confirmation.
4. New staff dashboard with secure browser sessions, branch scope, operational workflows, responsive layout and keyboard accessibility.
5. Durable notification outbox, retry/dedup, audit events and safe file lifecycle.
6. Typed client failure states, session routing, full premium UI/accessibility/motion work and meaningful widget/device tests.
7. Dependency upgrades/scans/SBOM, expanded CI, production-like load/soak/fault tests and restore proof.
8. iOS toolchain/signing, Android store artifacts, privacy/deletion policy, infrastructure and provider verification.

Current product verdict: **NOT READY — BLOCKERS REMAIN**. No dashboard or staff workflows are claimed implemented in work unit 1. No clinical/legal policy, deployment, risk acceptance or 10,000 requests/minute capacity is inferred from passing tests.


## Work unit 2: staff operations and local setup

Implemented a new React/Vite dashboard with same-origin cookie authentication, CSRF-protected writes, single-flight session refresh, branch switching, patient directory/create/edit, appointment list/booking/rescheduling, administrator staff invitations and access revocation, audit history, and resource/service/hours setup. No tokens are stored in browser localStorage. Browser testing exposed a stale CSRF challenge after authentication; mutations now fetch the current challenge, with a regression test.

V10 adds explicit branch membership, patient/branch associations, optimistic profile versions and audit metadata. Staff operations enforce branch scope on the server. Administrator privileges do not imply clinical permissions. Bootstrap is opt-in and refuses a second administrator bootstrap. Mobile bookings maintain branch association.

V11 adds service durations, resource timezones/hours/blocks, interval reservations, a PostgreSQL exclusion constraint, event history, and idempotency response records. Create/reschedule serialize relevant resources and reject overlaps. Calendar availability fetches occupied intervals once per day. Nonexistent/ambiguous DST local starts are rejected. Appointment transitions explicitly represent check-in, consultation, completion, cancellation and no-show; clinical steps require a clinician. Mobile requests without resources remain pending until staff confirms the existing record in place. Resource-backed changes route patients to the clinic. Flutter handles terminal/in-consultation/checked-in/unknown statuses without defaulting to confirmed, and no longer selects cancelled/no-show records as upcoming. AppointmentCard reflects updated input rather than retaining stale initial state.

V12 adds branch-scoped clinician template drafts and immutable published versions, explicit approval metadata, patient plan snapshots using the existing treatment_protocols model, optimistic plan transitions, and reason history. A new version does not alter existing patient instructions. Draft templates cannot be assigned; duplicate active plans and premature completion are rejected. Dashboard exposes clinical authoring only to branch clinicians. Existing unassigned legacy plans require authorized branch reconciliation; no clinical content or ownership was inferred.

Added root README, Docker Compose for a local PostgreSQL/API/Nginx dashboard/Mailpit stack, environment template and container build exclusions. Containers remain unexecuted here because Docker Engine is stopped. Java/PostgreSQL and Vite preview ran directly on localhost. Synthetic data only.

### Current remaining implementation and release gates

- Complete staff-created patient invitation/activation; current records stay pending with unknown generated passwords.
- Treatment session authoring/scheduling/appointment linkage, follow-up tasks, template retirement and complete plan lifecycle UI; no clinical suggestions are generated.
- Durable email outbox/retries/dedup, private uploads, audit storage permissions and retention, staff MFA, distributed rate limits and idempotency retention.
- Calendar resource/day/week views, session expiry UX, comprehensive responsive/accessibility checks, clinical and operational user acceptance.
- Full Flutter redesign/device acceptance, Xcode license/setup and iOS signing, store artifacts.
- Execute container setup and hosted CI; production provider integration, migration reconciliation, backup/restore, load/soak/fault tests, privacy/retention and infrastructure review.

Verdict remains **NOT READY FOR PRODUCTION**. This is a working local implementation increment, not completion of the full master brief. Nothing was deployed or pushed. CRM, payments, and report delivery remain deferred.


## Work unit 3: local cross-check requested on 26 September 2026

User clarified that the app should run locally for cross-check before hosting. No public deployment is authorized by this step.

- V13 adds an explicit invitation setup flag. Patient and staff invitations require an ACCOUNT_SETUP code and a chosen password before activation. Ordinary verification cannot bypass setup; blocked accounts stay blocked; setup does not grant verification reward points. Existing pending records are not guessed to be invitations.
- V14 links existing treatment_sessions to a unique resource reservation. Clinicians schedule sessions against confirmed appointments, with branch/patient scope and plan/session limits. Rescheduling updates linked session times; consultation/completion/cancellation/no-show update session status in the same transaction. Appointment row locking serializes those operations. Open sessions prevent plan pause/cancellation until resolved. Identical session-link retries return the existing session.
- V15 adds branch-scoped follow-up assignment, due dates, resolution reasons, optimistic versions and audit events. Dashboard has Follow-ups and linked-session controls.
- Added localhost API launcher with a generated signing key outside source control. Started verified Mailpit binary on localhost only; Java API now binds localhost explicitly. Built and served Flutter's JavaScript web target in a readable phone-width host container. Patient/staff credentials are in ignored `.local/ACCESS.md`.
- Removed deferred report entry points from the patient core workflow; the home shortcut opens Treatment Plan instead.
- Fixed dashboard logout when access cookies expire: refresh once, then revoke and clear the session. Added regression coverage.
- Live HTTP/SMTP smoke passed through both invitation flows, booking confirmation, clinical authoring, linked attendance and progress, follow-up and audit. Browser confirmed patient login persistence and the actual plan/session display.

Current review entry point: root `LOCAL_REVIEW.md`. Local cross-check is running. Production gates remain: durable provider delivery, staff MFA, private files, audit/retention controls, migration reconciliation, comprehensive device/accessibility acceptance, TLS/secrets/runtime DB roles, restore/load/fault testing and real infrastructure verification. Docker/iOS blockers remain. No claim that all master-prompt requirements are finished.

## Work unit 4: patient AI and human support — 26 September 2026

User selected OpenAI and the existing staff dashboard for human replies. V16 adds persisted branch-scoped support threads/messages and patient-scoped AI exchanges. Added authenticated patient/staff support endpoints, UUID deduplication, bounded history/rates, assignment/resolution with versions, reply notifications and audit metadata. OpenAI gateway uses Responses with explicit approved-plan/appointment projection, consent, no tools, `store:false`, bounded output and timeout. No keys/model are configured in the preview, so the UI truthfully directs patients to staff.

Replaced the Flutter placeholder with separate AI and Clinic team conversations, consent, treatment prompts, saved history, draft-preserving retries and foreground polling. Added the dashboard Patient support inbox. Browser verified a synthetic patient message, staff assignment/reply, reply display in the patient app, and resolution. Provider calls were mocked in automated tests; a live provider answer remains unverified. Root `AI_SUPPORT_SETUP.md` contains activation and release limits. No public deployment performed.
