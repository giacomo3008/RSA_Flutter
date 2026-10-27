# Verification results

Executed in the cloud on 27 October 2026 using Flutter 3.47.8, Dart 3.13.7 and Chromium/ChromeDriver 154.0.8037.57.

| Check | Actual result |
| --- | --- |
| `flutter pub get` / `flutter gen-l10n` | Passed; lockfile and generated ARB accessors included. |
| `dart format --output=none --set-exit-if-changed lib test integration_test test_driver` | Passed; 26 Dart files, no formatting changes. |
| `flutter analyze` | Passed: no issues. |
| `flutter test --reporter expanded` | **39 passed**: 27 domain/persistence tests and 12 widget tests. No skipped tests. |
| Browser integration through Flutter drive | **1 passed**, zero framework errors. Actual UI report → inbox → event conversation (does not claim) → explicit claim → diary → handover sources/amendment. |
| `./tool/build_web.sh` | Passed release web compilation, local engine/font assets, 46-file static-shell cache. The compiler's optional WASM dry run also succeeded; a dedicated `--wasm` deployment was not exercised. |
| `python3 tool/smoke_web.py` against the served release build | Passed startup, real attendance change, refresh persistence, service-worker installation, complete offline reopening, 390px mobile navigation/report and no JavaScript page errors. |
| Android debug APK / native device | Not run: Android SDK and emulator/device unavailable. |
| iOS simulator build / native device | Not run: Linux host has no macOS/Xcode/iOS SDK or simulator. |
| Hardware camera/microphone, TalkBack/VoiceOver, native lifecycle | Not verified on physical devices. Real capture adapters and explicit synthetic fallback controls are implemented. |

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
