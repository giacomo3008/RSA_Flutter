# Implementation scope

- [x] Shared Flutter Android/iOS/Web project; pinned dependencies and native permissions.
- [x] Adaptive Material 3 shell, public login/registration UI, confirmed logout, signed-out navigation guards, one-tap reporting, go_router history and Riverpod updates.
- [x] Connected twelve-entity domain, explicit ward-role capabilities, service-layer checks.
- [x] Durable Drift native/web storage, matching SQLite WASM/worker, transactional idempotency and claims.
- [x] Eight event types/default priorities, resident/other subject, editable time, place, optional notes/media and drafts.
- [x] Attendance/skills routing, explicit responsibility/outcomes, reminders/escalation and persisted deadlines.
- [x] Conversations with searchable colleague creation, ward/direct/private assistant threads, personal opt-in event discussions, replies/search/media and confirmed message-to-event drafts.
- [x] Deterministic assistant retrieval with tappable authorized source links; no external model calls.
- [x] Searchable diary and original-preserving amendments/version history.
- [x] Document review navigation, source preview, import/capture, manual transcription, explicit confirmation and retained original/correction history; remote OCR remains an integration.
- [x] Handover contributions, source links, review, physician validation where required, coordinator signature, amendments and assigned incoming acknowledgements.
- [x] Coordinator attendance/skills board; management aggregate filters; administrator assignment/integration/routing/audit views.
- [x] English ARB/localization, Italian fallback scaffold, UTC storage and IANA Europe/Rome display/shift boundaries.
- [x] Offline queue with authorization revalidation and honest states; explicit release static-shell service worker.
- [x] Unit/widget tests, browser integration driver, release build and browser smoke tools.
- [ ] Real backend authentication, protected storage, multi-device delivery and background push.
- [ ] Native SDK/device builds and camera/audio/lifecycle/accessibility acceptance on Android/iOS.
- [ ] Real OCR/transcription, original document-image extraction pipeline, clinical policy approval and production retention/access audit.
- [ ] Full per-shift resident allocation and independent concurrent per-ward attendance ledger.
- [ ] Italian translations and independent production accessibility review.

The uploaded Flutter/Dart specification and RSA_agentic_AI requirements, cross-checked against plan_0 and guida_1, are the implementation references. The large React ZIP could not be transferred through the available 32 MiB attachment tool; its source and styling were not inspected or copied. The handover redesign follows the supplied React screenshot and written requirements rather than claiming pixel parity with that archive.
