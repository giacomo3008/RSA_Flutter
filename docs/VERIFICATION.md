# Verification results

Workspace redesign checked on 28 October 2026; handover presentation, staff-update and role-navigation checks repeated on 29 October 2026 using Flutter 3.47.8, Dart 3.13.7 and Chromium/ChromeDriver 154.0.8037.57.

| Check | Actual result |
| --- | --- |
| `flutter pub get` / `flutter gen-l10n` | Passed; lockfile and generated ARB accessors included. |
| `dart format --output=none --set-exit-if-changed lib test integration_test test_driver` | Passed; 43 Dart files, no formatting changes. |
| `flutter analyze` | Passed: no issues. |
| `flutter test --reporter expanded` | **110 passed**: 57 domain/persistence tests and 53 widget tests. No skipped tests. |
| Browser integration through Flutter drive | **1 passed**, zero framework errors. Actual UI report → inbox → event conversation (does not claim) → explicit claim → saved correction with safe dialog dismissal → diary → handover sources/amendment. |
| `./tool/build_web.sh` | Passed release web compilation, local engine/font assets, 46-file static-shell cache. The compiler's optional WASM dry run also succeeded; a dedicated `--wasm` deployment was not exercised. |
| `python3 tool/smoke_web.py` against the served release build | Passed handover/document/conversation page navigation, hidden unopened event discussions, startup, real attendance change, refresh persistence, service-worker installation, complete offline reopening, 390px mobile navigation/report and no JavaScript page errors. |
| Android debug APK / native device | Not run: Android SDK and emulator/device unavailable. |
| iOS simulator build / native device | Not run: Linux host has no macOS/Xcode/iOS SDK or simulator. |
| Hardware camera/microphone, TalkBack/VoiceOver, native lifecycle | Not verified on physical devices. Real capture adapters and document image import are implemented; optional sample capture remains confined to explicitly enabled development builds. |

The domain tests exercise role/ward isolation, on-duty/availability eligibility, idempotency, atomic responsibility, escalation, offline synchronization and revoked permissions, original-preserving amendments, OCR review separation, handover review/validation/signature/acknowledgement, real SQLite close/reopen with drafts/outbox/media, IANA shift boundaries including 9/11-hour DST nights, explicit multiple ward roles, and stale queued operations across persona changes.

Widget checks include 360px width and increased text scale, expanded console navigation, visible report submission, management/admin clinical deep-link guards, and clearing old clinical navigation on persona changes. The Home refresh additionally verifies live availability/check-in/check-out updates, routing eligibility, pending-save double-click prevention, removal of demo labels and connection badges, account context, and blocked development-only routes in default builds.

## Reproduce the browser integration

In this cloud machine, source `tool/cloud_env.sh`, then run the matching driver in a separate process:

```sh
/workspace/browser-tools/chromedriver-linux64/chromedriver --port=4444
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/workflow_test.dart -d web-server \
  --chrome-binary=/usr/bin/chromium --headless \
  --web-browser-flag=--no-sandbox \
  --web-browser-flag=--disable-dev-shm-usage
```

The browser integration writes `build/integration_response_data.json`; the successful run contains `frameworkErrors: []`. Tests use an isolated browser origin and reset synthetic data there. Do not point the test runner at a session whose demo changes you want to keep.

For the release smoke check, keep `python3 tool/serve_web.py --port 8080` running and invoke `python3 tool/smoke_web.py`. This uses the installed Python Playwright library and an isolated Chromium context. It generates the screenshots in `docs/screenshots/`.

## Scope of these results

Current-machine checks do not establish native-device readiness, production security, real AI behavior, remote push, backend delivery, or restoration in a new cloud task. Cloud configuration draft saving and Git publication are separate from publishing the prepared environment snapshot.

Correction-dialog regression checks cover saving a correction while retaining the original text and history, cancelling without a new version, and closing with an outcome. The input controller is now owned by the dialog state and is disposed after the exit transition, rather than immediately when showDialog returns.

## Workspace redesign coverage

New tests exercise personal event-conversation subscriptions and SQLite reopening, direct-chat reuse and ward isolation, document source hashes/manual transcription/review/correction history, coordinator and administrator authority boundaries, management configuration scope, edited handover review invalidation, immutable signed narratives and full source snapshots, shift separation, and acknowledgement bound to a specific record/version.

The new widget workflows cover Open chat, the + colleague picker, document confirmation and subsequent correction, coordinator draft editing, historical versions without current-version actions, and seven role/workspace pages at 360px with 1.3× text. Retained reports, document reviews, handovers and conversations remain readable when their former authors move to another ward, while strict staff-profile lookup remains denied.

Release screenshots include handover on desktop/mobile, Document review and Conversations. The React ZIP exceeded the transfer limit; the supplied screenshot and three PDFs were inspected instead. No real AI, OCR or SSO provider was used or represented as connected.

## Handover presentation and staff updates

The 29 October checks add seven positive role-navigation cases and eight focused handover checks: pending updates preserve every signed field, unauthorized inclusion is denied, coordinator inclusion preserves authors/times and archived receipts, stale record/version submissions fail, SQLite reopening retains pending updates, signed staff can submit through the visible input, coordinators include updates through the visible button, grouped history avoids duplicate version cards and signed report cards retain their historical status after live closure.

The release browser check also types and submits an update, reloads the handover and checks that version 1 remains signed. Updated screenshots include report cards and the grouped history. The browser integration completed with frameworkErrors empty. All seven role pages are also covered by the existing narrow-screen checks.

## Public access and first chat opening

Nine widget regressions cover default login, signed-out clinical/administrative/unknown URL guards, empty-field entry as Emily even when a different local account was selected previously, registration navigation, logout cancellation and confirmation with cleared navigation, both access forms at 320px with enlarged text, and immediate first conversation opening on phone and desktop with a long thread. Chat routes use NoTransitionPage and the reverse viewport starts at its minimum extent before later frames.

Existing care and role workflow tests explicitly inject an authenticated fixture session; the production provider remains signed out by default. No user-facing role selector or credential-validation claim was introduced.

The release-browser check covers login/registration, no-data login, first conversation opening, logout confirmation/cancellation, browser Back and direct URL denial while signed out, and renewed frontend entry after full reload. Record persistence and offline reopening are checked after entering through the public login page. The temporary session is intentionally not persisted and no backend authentication or account creation is performed.
