# Backend hosting and Google Play readiness — 5 October 2026

**Decision: not ready for public patient production or Play production submission.** Core automated checks pass. A restricted staging deployment is the next appropriate environment; production infrastructure has not been provisioned or tested. Google Play approval cannot be guaranteed by source review or unit tests.

Reviewed unified repository baseline: `0bf4d9f` (current working source, plus the release-build fixes described below). No existing patient records were modified. Tests used a newly created, isolated PostgreSQL database. Test credentials, logs, database contents and signing material are not included in this report or GitHub.

## Executed verification

| Check | Result |
| --- | --- |
| Full backend PostgreSQL regression | 94 discovered: 90 passed, 0 failures, 0 errors, 4 skipped |
| Skips | Two OpenAiLiveTests and two AssistantLiveFlowTests; explicitly opt-in provider tests, not rerun in this audit |
| Fresh Flyway migrations | V1–V17 successful against an empty disposable database |
| Backend package | Java 21 Maven deployment JAR built successfully |
| Flutter | Analyzer clean; 39 tests passed in the unified checkout |
| Staff dashboard | 6 tests passed; production bundle built; npm install audit reported no vulnerabilities in its locked dependency set |
| Android release guard | Build fails at verifyReleaseConfiguration with the intended missing-upload-key message; no distributable AAB produced |
| Android SDK configuration | Pinned Flutter 3.38.6 resolves target SDK 36; AGP 8.11.1. Final merged release artifact remains unverified |
| Docker runtime | Not executed: Docker Engine is not running on this machine |

Backend tests cover authentication lifecycle, authorization, concurrent appointments, resource booking, clinical authoring, staff operations, home endpoints, support, and AI retrieval/privacy. They do not prove capacity, complete medical safety, full Android device acceptance, production SMTP delivery, backup recovery, or deployed infrastructure security. No full Java dependency vulnerability scan or penetration test was performed.

## Release configuration fixes

`ant/android/app/build.gradle.kts` no longer falls back to debug signing for release builds. A release pre-build task requires upload signing configuration and an explicit HTTPS API endpoint, rejecting local/example defaults. Normal debug builds remain available. The Kotlin JVM target was migrated to the compilerOptions DSL after the build check exposed its deprecated configuration. The missing-key negative check was executed; a successful signed release is still pending provision of the real upload key and hosted API. Endpoint validation checks syntax/configuration, not server reachability or ownership.

## Backend public-launch blockers

| Priority | Evidence | Required completion |
| --- | --- | --- |
| P0 | SecurityConfig permits `/uploads/**`; WebMvcConfig directly serves upload storage | Replace public patient-photo serving with ownership/role-authorized delivery; test anonymous and other-patient denial; update image clients accordingly |
| P0 | `infrastructure/compose.yaml` remains local-only, with Mailpit and insecure local staff cookies | Prepare production Compose/reverse proxy, HTTPS, secure cookies, private database network, persistent database/uploads, secret injection and resource limits |
| P0 | Hosted destination/domain and production credentials are unconfigured | Configure hosting, rotate the previously shared AI credential, verify production health and core flows on HTTPS |
| P1 | EmailService uses asynchronous in-process delivery; no durable outbox/retry evidence | Verify actual invitation/reset/OTP delivery and implement reliable failure/retry handling |
| P1 | Staff authentication has no MFA implementation found | Add staff MFA and review staff role/branch access before handling real clinic records |
| P1 | No production backup/restore execution | Configure encrypted off-server backups, restore into a separate DB, document recovery and failed-deployment procedure |
| P1 | Clinical/marketing source content remains imported from the website | Clinic approval of protocols, claims, service availability and retention; do not treat website advertising as clinical evidence |

## Google Play acceptance matrix

| Requirement | Current assessment / next step |
| --- | --- |
| Account deletion | Missing patient account-deletion path and external request page. AI-history clearing and staff soft deletion are not substitutes. Implement request handling, identity checks, session revocation and fulfillment; disclose legitimately retained medical records and retention periods. [Policy](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) |
| Privacy policy | No application privacy-policy entry/link found. Publish an accessible HTML policy and link it in-app and Play Console; describe health/profile data, photos, chat, OpenAI processing, hosting, purposes and retention. A separate terms document does not replace it. [Health policy](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en&ref_topic=9877466) |
| Health declaration and medical claims | Complete Health apps declaration. Likely applicable categories include Healthcare Services and Management and Medication and Treatment Management; owner must confirm actual features. If not regulated as a medical device, include the required non-medical-device disclaimer in the store description and advise professional consultation. Review weight-loss/therapy marketing for misleading claims. [Declaration](https://support.google.com/googleplay/android-developer/answer/14738291?hl=en) |
| AI reporting | Chat has copy/history/privacy controls, but no explicit report/flag-response flow found. Add in-app reporting routed to staff/moderators, plus review and mitigation procedures. [AI policy](https://support.google.com/googleplay/android-developer/answer/13985936) |
| Data safety | Not verified in Console. Inventory names/email/phone/user IDs, health/treatment/appointment information, photos and messages; document collection, processing, sharing exceptions, encryption and deletion accurately. Review third-party SDK/provider behavior. Do not submit guessed answers. [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) |
| Target SDK | Source configuration resolves API 36, matching the current new-app requirement; inspect the final bundle too. [Target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) |
| Native library compatibility | Final AAB and all native libraries must be checked for 16 KB page-size compatibility and tested on a suitable device/emulator. Not verified here. [Android guidance](https://developer.android.com/guide/practices/page-sizes) |
| Signing / release endpoint | Upload keystore absent in unified checkout; release safely blocked. Configure Play App Signing and secure upload-key backup. Supply real HTTPS API and increment version code for subsequent releases. |
| Developer/account and testing | Console not inspected. Confirm organization eligibility/verification for this clinic health app. Where applicable, newer personal accounts require 12 continuously opted-in testers for 14 days before requesting production access. [Testing](https://support.google.com/googleplay/android-developer/answer/14151465) |
| Reviewer access / store content | Prepare a dedicated synthetic reviewer login and all access instructions, screenshots, support contact, content rating, target audience and accurate listing. Never give reviewers a real patient account. |
| Physical devices | Test login/recovery, photo picker, appointment/timezone flows, approved treatment display, support/AI, expiry/logout, offline/retry, accessibility and deletion on actual Android release builds. |

## Next release sequence

1. Close privacy/photo/deletion/AI-reporting gaps and obtain clinic-approved policy/retention details.
2. Deploy restricted staging with synthetic accounts, then verify email, storage persistence, authorization and backup restore.
3. Build and inspect the signed Android bundle against the live staging endpoint, run internal/required closed testing and Play pre-launch checks.
4. Complete Console declarations, reviewer access and store listing. Promote tested server configuration and release artifacts only after acceptance.

This report distinguishes verified behavior, source findings, and pending operational/Console tasks. It is not legal certification or an assurance of Play approval.
