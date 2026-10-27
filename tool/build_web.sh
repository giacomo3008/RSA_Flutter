#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --no-web-resources-cdn
python3 tool/build_app_shell.py
