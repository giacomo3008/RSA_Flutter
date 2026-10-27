# Implementation scope

- [x] Shared Flutter Android/iOS/Web project; pinned dependencies and native permissions.
- [x] Adaptive Material 3 shell, one-tap reporting, go_router history/guards, Riverpod updates.
- [x] Connected twelve-entity domain, explicit ward-role capabilities, service-layer checks.
- [x] Durable Drift native/web storage, matching SQLite WASM/worker, transactional idempotency and claims.
- [x] Eight event types/default priorities, resident/other subject, editable time, place, optional notes/media and drafts.
- [x] Attendance/skills routing, explicit responsibility/outcomes, reminders/escalation and persisted deadlines.
- [x] Team/direct/event/private assistant chat, replies/search, media, unread state and confirmed message-to-event drafts.
- [x] Deterministic assistant retrieval with tappable authorized source links; no external model calls.
- [x] Searchable diary and original-preserving amendments/version history.
- [x] Simulated OCR extraction review; original text retained; clinical validation separate.
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

The uploaded Flutter/Dart specification is the implementation reference. The large React ZIP could not be transferred through the available 32 MiB attachment tool; its source and styling were not inspected or copied. The application therefore follows the written design direction rather than claiming pixel parity with that archive.
