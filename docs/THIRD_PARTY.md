# Bundled assets

- Manrope variable font: Google Fonts `ofl/manrope/Manrope[wght].ttf`; its SIL Open Font License is bundled as `assets/fonts/OFL.txt`.
- `web/sqlite3.wasm`: official `simolus3/sqlite3.dart` GitHub release `sqlite3-3.8.0`, matching `pubspec.lock`. SHA-256: `efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37`.
- `web/drift_worker.dart.js`: upstream worker supplied by the installed Drift 2.35.3 package, matching `pubspec.lock`. SHA-256: `a54b81412d4c4ab56653bb9e4c02912b0820bb37e2bba00722ddef4d78083d4a`.
- App icons are generated simple RSA cross artwork. The sample photo is synthetic and the sample audio is a generated tone, not patient media.

When upgrading Drift/sqlite3, replace the worker/WASM assets together using their official releases, verify provenance/checksums, rebuild the shell, and rerun storage/offline browser checks. Flutter's package license registry supplies Dart package notices in the built application assets.
