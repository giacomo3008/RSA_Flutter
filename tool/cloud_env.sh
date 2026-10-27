#!/usr/bin/env bash
# Source this helper in Codex cloud; local Flutter installations do not need it.
export PATH="/workspace/flutter-sdk/bin:$PATH"
export PUB_CACHE=/workspace/.pub-cache
export XDG_CONFIG_HOME=/workspace/.config
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.dartServer
export DASH__SUPPRESS_ANALYTICS=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export CHROME_EXECUTABLE=/usr/bin/chromium
