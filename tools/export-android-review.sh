#!/usr/bin/env bash
set -euo pipefail
: "${TOOLING:?Set the previously approved isolated Android tooling directory}"
: "${OUT:?Set a private acceptance output directory}"
: "${BASELINE_APK:?Set the installed v0.1 debug APK for signer comparison}"
: "${GODOT:=godot}"
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$TOOLING/env.sh"
mkdir -p "$OUT"
APK="$OUT/velvet-circuit-0.2.0-alpha-debug.apk"
"$GODOT" --headless --path "$ROOT" --export-debug Android "$APK" 2>&1 | tee "$OUT/android-export.log"
SIGNER="$ANDROID_HOME/build-tools/35.0.1/apksigner"
"$SIGNER" verify --verbose --print-certs "$BASELINE_APK" > "$OUT/baseline-signature.txt"
"$SIGNER" verify --verbose --print-certs "$APK" > "$OUT/apk-signature.txt"
diff <(grep 'Signer #1 certificate SHA-256 digest:' "$OUT/baseline-signature.txt") <(grep 'Signer #1 certificate SHA-256 digest:' "$OUT/apk-signature.txt")
"$ANDROID_HOME/build-tools/35.0.1/aapt" dump badging "$APK" > "$OUT/apk-manifest.txt"
grep -q "versionCode='2' versionName='0.2.0-alpha'" "$OUT/apk-manifest.txt"
grep -q "native-code: 'arm64-v8a' 'x86_64'" "$OUT/apk-manifest.txt"
! grep -q 'android.permission.INTERNET' "$OUT/apk-manifest.txt"
sha256sum "$APK" > "$APK.sha256"
printf '%s\n' 'Export verified; NOT installed, visually accepted or approved for publication.'
