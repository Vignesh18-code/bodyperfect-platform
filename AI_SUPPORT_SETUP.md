# Patient AI chat and clinic support

Updated 3 October 2026. The chat implementation is ready for local acceptance testing. This is not a certification of the full app for public clinical use.

## Try the local app

- Patient app: http://localhost:5174/ → Chat → AI assistant.
- Staff dashboard: http://127.0.0.1:5173/?view=support&branch=BURJUMAN → Patient support.
- Keep the existing IntelliJ backend running on port 8080 with the `local` profile and existing PostgreSQL database. Do not create a new patient account or change databases for this feature.
- The local profile imports `../.local/ai.properties`, relative to the backend working directory (`clinicapp`). The configured test key is stored only there with owner-only file permissions. GPT-4.1 was verified with the OpenAI project.
- If IntelliJ has not reloaded configuration, restart **ClinicappApplication**. Refresh the patient browser or relaunch the rebuilt simulator app.

## What clients can do

Ask about BodyPerfect services, locations, their approved active care plans, treatment sessions, upcoming appointment summaries, and reward points. The assistant uses current authenticated records and relevant conversation history. Clients can open booking or treatment screens, or switch to their clinic's human support channel. Booking still requires confirmation in the appointment form. AI cannot prescribe, change care plans, book/cancel on its own, or retrieve another client's records.

The compact chat screen includes starter questions, visible reply status, selectable/copyable answers, source links, explicit action buttons, history pagination, retry with preserved drafts, and memory controls. Staff messages are persisted and polled while the screen is active. This is asynchronous support, not emergency monitoring or a guaranteed live response.

## Knowledge files and retrieval

- `knowledge/bodyperfect/pages/`: readable Markdown snapshots of 70 public BodyPerfect pages.
- `knowledge/bodyperfect/manifest.json`: source URLs, retrieval timestamps, hashes, and import failures.
- `clinicapp/src/main/resources/knowledge/bodyperfect.json`: corresponding packaged runtime corpus.
- `knowledge/bodyperfect/service-directory.md` and the runtime `bodyperfect-services.json`: a concise list of the 12 service categories from https://www.bodyperfect.ae/services/. Program names are labels, not promises of medical outcomes.
- `scripts/import-clinic-knowledge.py`: reproducible public website import. Run `python3 scripts/import-clinic-knowledge.py`, review changes and the manifest, then rebuild/restart the backend. Review the curated service directory when website categories change.

Retrieval uses local weighted lexical ranking over overlapping excerpts, returning up to six snippets and at most two per source page. It is retrieval-augmented generation, not a vector/embedding database. General service-list queries use the curated directory instead of unrelated promotional excerpts. Citations are selected from retrieved snippets and validated against their IDs; the model cannot introduce arbitrary source links. Links identify supporting pages, not independent medical validation. No uploaded patient files or arbitrary websites are ingested.

The snapshot is dated 2 October 2026. One site link (`/service/indiba/`) failed during import; the site's `/service/indeba/` page was available. There is no automatic website refresh. Pricing, schedules and clinical claims require clinic review. Website marketing is treated as untrusted content; prompts prohibit outcome guarantees and prescribing. A narrow deterministic output check also suppresses IV marketing benefit claims observed in live tests. These checks are not a comprehensive clinical safety classifier.

## Memory, consent and privacy

- Patient identity is derived from the authenticated session. No patient ID supplied by the client selects AI context.
- Only an explicit projection is sent: the signed-in client’s name and preferred treatment, up to three approved active plans (instructions capped at 4,000 characters each), ten appointment summaries, twenty treatment sessions, points and linked branch names. Passwords, tokens, OTPs, account contact fields, internal staff notes and other patients' records are excluded. Bounded summaries may be incomplete; they are not a full medical record export.
- With memory enabled, the assistant receives up to sixteen recent completed exchanges, up to three relevant older exchanges, and an optional client preference note. Older recall uses PostgreSQL English full-text matching; semantic/multilingual recall is limited. Recent context still supports ordinary follow-ups.
- Memory preferences persist in PostgreSQL across devices. Clients can turn recall off, edit their note, or clear AI history and the note. Turning memory off stops reuse; it does not delete displayed history. Human-support messages are separate and are never automatically forwarded from AI.
- AI requests require an explicit consent dialog per screen session. The backend records the consent version. Memory defaults on, disclosed before the first AI request.
- AI exchanges expire after 90 days; an hourly task deletes expired rows, and history queries exclude expired rows immediately. User preference notes remain until edited or cleared. Operational usage metadata is kept for 48 hours so clearing history cannot reset the daily limit. Staff-support retention and backup deletion must follow the clinic's approved policy.
- Free-text messages and approved instructions may contain personal information. Credential-pattern blocking is limited, not general anonymization or DLP.
- Responses requests use `store:false`. This does not mean zero provider retention. Review the OpenAI [data controls](https://developers.openai.com/api/docs/guides/your-data) and clinic privacy arrangements before sending real patient data in production.

## Reliability and configuration

Flyway V17 adds memory preferences, citation/action metadata, indexed history recall and a usage ledger. Existing conversations and accounts are preserved. Requests use persisted UUID idempotency; completed retries reuse saved answers. Unknown connection outcomes keep the same UUID; known failed replies can be retried with a new UUID. One pending request and 30 attempts per rolling 24 hours are allowed per patient, including failures. Provider timeout is 22 seconds with no automatic provider retry. Staff messaging remains available if AI is disabled or the provider fails.

Production environment settings:

```text
APP_AI_ENABLED=true
OPENAI_API_KEY=<secret supplied by the hosting secret manager>
OPENAI_MODEL=gpt-4.1
```

Never put provider secrets in Flutter, dashboard environment files, source control, logs or screenshots. Rotate the shared testing key before launch and set an OpenAI project budget with alerts. The local key file is not a deployment mechanism. Follow the existing deployment/database instructions; do not use an older preview launcher to switch away from the active local database.

## Validation and launch acceptance

Automated checks cover consent, ownership and branch isolation, private memory, memory opt-out, older recall, pagination, source filtering, retention, daily limits after deletion, credential rejection, persisted duplicate requests, failed provider replies, staff notification/audit and booking boundaries. Flutter checks cover chat consent, retries, explicit booking navigation, staff fallback, memory changes/clear confirmation, and small-screen keyboard/text scaling.

Live provider evaluations use public website information and synthetic memory only; no real patient record was used. They test IV service explanation, branch location, remembered language preference, and refusal of guarantees/new injection prescriptions. Review `clinicapp/target/chat-live-evidence.json` locally for the latest generated answers; it is generated evidence, not application content.

Before hosting: the clinic must review the website corpus and clinical response examples, approve provider/consent/retention arrangements, replace the test key, and complete staging HTTPS, backup/restore, monitoring and real-device acceptance. Confirm branch contact details and staff response procedures. This implementation does not prove every possible AI answer is safe or make the rest of the platform launch-ready.

### Recorded local checks — 2 October 2026

- Flutter analyzer: no issues. Full Flutter suite: 37 passed; the five chat tests were rerun after the final accessibility/responsive changes and passed.
- PostgreSQL-backed/backend checks: 28 passing tests across SupportTests (10), AssistantRagTests (9), OpenAiGatewayTests (3), HomeEndpointTests (4), OpenAiLiveTests (1) and AssistantLiveFlowTests (1).
- Seven final live OpenAI scenarios across the two opt-in suites. The authenticated flow used a synthetic approved plan in the isolated `bp_chat_audit_20261002` database, persisted preferences/history, and source-linked all 12 service categories.
- Additional regression: a long plan returns its nearest upcoming session, rather than only the latest dates. Canceled/completed/no-show appointments do not crowd out upcoming appointment context.
- Mobile visual review: compact starter screen, consent dialog, reply/source/action cards, memory sheet, and narrow-phone layout. Actual iPhone 17 Pro Max simulator launch and Chat navigation succeeded against the existing local backend.
- Backend health returned UP; active local database migration version is 17. Local patient data was not replaced by test fixtures.
- The provided key was found zero times in checked application source, website knowledge, scripts or the built web client; its private local file has permissions 0600.
- Flutter web and simulator debug builds are used for local acceptance. Existing web Wasm compatibility notices and the simulator native_assets/SdkRoot diagnostic are not evidence of a release archive build. App Store/release signing and a real physical-device check remain outside this chat acceptance.


### Personalization and continuity update — 3 October 2026

The missing-name issue was caused by omitting `full_name` from the provider projection. The authenticated name and preferred treatment are now included; account credentials, email, phone and other clients' records remain excluded. The consent version is now `care-profile-memory-v3`, with matching disclosure in the patient UI.

Recent conversation is replayed as ordered user/assistant messages, with the current database context provided separately. There is no five-minute conversation timeout. Up to sixteen recent completed exchanges plus three relevant older exchanges within the 90-day retention window are used when memory is enabled. Older recall matches significant query terms with OR semantics rather than requiring every word. This follows [OpenAI's conversation-state guidance](https://developers.openai.com/api/docs/guides/conversation-state) while keeping durable history in the clinic database and `store:false` at the provider.

The smaller welcome screen greets the client by name, provides direct starter questions, and shows follow-up question chips after replies. Diet-plan requests lead to consultation guidance; the clinician determines whether blood tests are indicated. The assistant must not invent mandatory test panels or prescribe a personalized diet. Booking actions still open the appointment form for client confirmation.

Verification: 39 Flutter tests passed, including interactive follow-ups and reloading earlier history after recreating the chat screen. The live authenticated synthetic evaluation answered the registered name, explained the diet consultation process with conditional testing, and recalled the diet discussion after saved timestamps were moved six minutes into the past. This is a simulated elapsed-time regression, not a timed six-minute manual wait. The two live flow tests passed alongside the updated privacy, memory and gateway regression tests. Evidence: `clinicapp/target/chat-continuity-evidence.json`.

### Pricing response refinement — 3 October 2026

The concierge now leads with service-specific pricing guidance rather than saying the website lacks prices. Session-based treatment quotes depend on the assessed treatment/session plan; diagnostic queries such as DNA testing require confirming the test or panel, not a session count. Verified prices should be given with their conditions when present. Unknown amounts, discounts, package inclusions and free consultations must never be invented. Booking and clinic-team buttons remain explicit next steps.

Validation: four gateway regression tests and one live pricing evaluation passed, covering three synthetic questions (DNA, session-based treatment, and pressure to guess an amount). Generated responses are in `clinicapp/target/chat-pricing-evidence.json`. No patient records were sent by these tests. Prompt examples follow the [official OpenAI prompting guidance](https://developers.openai.com/api/docs/guides/prompt-engineering). Existing saved answers are unchanged; the guidance applies to new replies.
