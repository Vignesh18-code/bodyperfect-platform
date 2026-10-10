# Verification checklist — 9 October 2026

Code checked: `bce9901`, unified repository `bodyperfect-platform`.

**Result:** local automated checks passed and the hosted API is healthy. This is not full production or Play release sign-off. Hosted authenticated workflows and release operations below remain pending.

## Checks performed in this run

| Check | Result | Evidence / limits |
|---|---|---|
| Backend full test suite against fresh PostgreSQL | PASS | 112 discovered, 108 passed, 0 failures/errors, 4 optional live-AI tests skipped. Dedicated database `bp_final_check_20261009` removed after completion; no production data changed. |
| Flutter static analysis | PASS | `flutter analyze`: no issues. |
| Flutter tests | PASS | All 49 tests passed. |
| Dashboard tests | PASS | All 8 tests passed. |
| Dashboard production build | PASS | Vite production build completed. |
| Hosted API health | PASS — live | HTTPS `/actuator/health` returned 200 and UP. |
| Hosted API readiness | PASS — live | HTTPS `/actuator/health/readiness` returned 200 and UP. |
| Anonymous access denied | PASS — live | `/api/appointments`, `/api/user/profile`, `/api/reports`, `/api/reports/1/download` returned 401. This does not prove report routes or latest migrations are deployed; the global security filter can reject any protected path. |
| Simulator current screen | OBSERVED | Running app shows signed-in home, initial avatar, points, programs, quick actions and no-active-treatment state. This is a visual observation, not a complete interactive device test. Simulator UI automation timed out. |
| Android local release signing | NOT CONFIGURED HERE | `ant/android/key.properties` absent. A separate CI signing setup was not verified. |

## Functional coverage verified locally

These passes refer to automated tests against test data/mocked external services, not newly executed production customer journeys.

- [x] Authentication lifecycle, ownership checks and staff/branch authorization.
- [x] Staff MFA tests and CSRF protection, including report upload.
- [x] Appointment creation, conflict/concurrency protection, confirmation in place, rescheduling and version checks.
- [x] Failed/rolled-back voucher booking does not consume voucher; claim persists and cannot be repeated.
- [x] Claimed home voucher remains hidden after home recreation; ordinary appointments do not show voucher visit messaging.
- [x] Appointment status text, clinic-contact routing, telephone fallback and retry after load failure.
- [x] Reports restricted to the owning patient and authorized branch clinicians; encrypted PDF storage and private download headers.
- [x] Invalid/oversized report upload rejection; withdrawal hides report and disables its download while retaining audit metadata.
- [x] Report UI has zero height when empty, supports download retry and prevents duplicate taps.
- [x] Home search, scrolling header, service/program navigation and reduced-motion behavior covered by Flutter tests.
- [x] Narrow-screen/large-text scenarios covered for home, visit guide and reports. These are not a complete accessibility or device-performance audit.
- [x] AI retrieval, gateway and support-conversation tests pass locally. Four live-AI tests were skipped, so live response quality and current provider credentials are not certified by this run.
- [x] Email delivery/outbox tests pass locally. OTP delivery was previously reported working by the user; no new external OTP delivery was performed in this run.

## Hosted end-to-end acceptance — still required

Use clearly identified test patient/staff accounts and synthetic reports.

- [ ] Verify Railway's successful deployment corresponds to the intended Git commit and report migration V22 is applied.
- [ ] Patient makes ordinary booking → correct branch staff sees it → staff confirms → patient refresh shows the same appointment confirmed.
- [ ] Reschedule from staff/app as supported → both views show one updated appointment, and the former slot is released.
- [ ] Eligible test patient books with voucher → congratulations appears once → voucher section disappears → remains absent after logout/login and app restart. Ordinary booking must not show that congratulations.
- [ ] Clinician uploads a synthetic PDF → correct patient sees it → native Save/Share opens a readable PDF → another patient cannot access it → withdrawal removes it after refresh.
- [ ] No reports: no report section or empty gap. Report request failure: retry is shown rather than claiming the patient has no reports.
- [ ] Assign a treatment plan/session in the dashboard → patient treatment page and home next-session card match it.
- [ ] Chat: live provider response, patient-specific context, continuity after five minutes/app restart, staff handoff/reply and failure/retry handling.
- [ ] Fresh OTP login/recovery with the hosted API and logout/session refresh on a physical device.
- [ ] Directions and telephone buttons on a physical phone; verify branch contacts are the intended public numbers.
- [ ] Recheck keyboard, large text, small screens, slow/offline recovery and scrolling on release-mode physical Android/iOS devices.

The hosted staff dashboard URL and a signed-in test staff session are needed to complete the staff-to-patient checks. Do not share passwords, OTPs or secret keys in chat.

## Release operations — not verified by passing tests

- [ ] Production database backups and isolated restore, including recovery of the stable report/MFA encryption key.
- [ ] Durable profile-image storage, restart behavior, monitoring and rollback procedure.
- [ ] Real branch details, treatment content and published policy/contact links checked for the shipped app; complete outstanding privacy/account-deletion operational requirements.
- [ ] Server-only provider secrets configured and any previously shared keys replaced; no secrets in Flutter/GitHub artifacts.
- [ ] Signed Android App Bundle built with the hosted API URL; signing kept outside source control.
- [ ] Install through Play internal testing and repeat the critical patient/staff flows.
- [ ] Review current Play Console declarations, data safety, health/privacy disclosures, reviewer access and applicable testing requirements. No Play policy acceptance assessment was performed in this run.

## Reproduction and evidence

- Backend: `bash clinicapp/scripts/test-postgres.sh -q` with a newly created disposable PostgreSQL database supplied through TEST_DATABASE_URL/USERNAME/PASSWORD. Results: `clinicapp/target/surefire-reports/TEST-*.xml` (regenerated by later runs).
- Flutter: `flutter analyze` and `flutter test` in `ant/`.
- Dashboard: `npm test` and `npm run build` in `dashboard/`.
- Hosted base URL: https://bodyperfect-platform-production.up.railway.app
- No live bookings, reports, patient records or credentials were modified during this verification.
