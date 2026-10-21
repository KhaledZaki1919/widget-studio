#!/usr/bin/env bash
# Packages an unsigned WidgetStudio.app into an .ipa for Sideloadly (ADR-003).
# The binaries are ad-hoc signed ("-": no certificate, no secret) only to embed the
# requested entitlements, so the re-signing tool can see that we ask for an App Group.
# Usage: build-ipa.sh <path/to/WidgetStudio.app> <output.ipa> [--no-healthkit]
# --no-healthkit drops the HealthKit entitlement from the app (fallback if Sideloadly
# refuses it on a free Apple ID; ADR-005).
set -euo pipefail

APP="$1"
OUT="$2"
NO_HEALTHKIT="${3:-}"
CONFIG_DIR="$(cd "$(dirname "$0")/../Config" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/Payload"
cp -R "$APP" "$WORK/Payload/"
BUNDLE="$WORK/Payload/$(basename "$APP")"
APP_NAME="$(basename "$APP" .app)"

APP_ENTITLEMENTS="$WORK/$APP_NAME.entitlements"
cp "$CONFIG_DIR/$APP_NAME.entitlements" "$APP_ENTITLEMENTS"
if [ "$NO_HEALTHKIT" = "--no-healthkit" ]; then
  # PlistBuddy, not plutil: plutil reads the dots in the key as a nested key path.
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.healthkit" "$APP_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.healthkit.access" "$APP_ENTITLEMENTS" 2>/dev/null || true
  if grep -q "com.apple.developer.healthkit" "$APP_ENTITLEMENTS"; then
    echo "error: HealthKit entitlement still present in the no-HealthKit variant" >&2
    exit 1
  fi
fi

# The widget extension must be embedded.
if ! ls "$BUNDLE"/PlugIns/*.appex >/dev/null 2>&1; then
  echo "error: no widget extension in $(basename "$BUNDLE")/PlugIns" >&2
  exit 1
fi

# Inner bundles first, then the app.
for appex in "$BUNDLE"/PlugIns/*.appex; do
  name="$(basename "$appex" .appex)"
  codesign --force --sign - --timestamp=none \
    --entitlements "$CONFIG_DIR/$name.entitlements" "$appex"
done
codesign --force --sign - --timestamp=none --entitlements "$APP_ENTITLEMENTS" "$BUNDLE"

# Without UILaunchScreen iOS runs the app letterboxed in legacy compatibility mode.
if ! plutil -extract UILaunchScreen xml1 -o - "$BUNDLE/Info.plist" | grep -q "<dict>"; then
  echo "error: UILaunchScreen is missing or empty in Info.plist" >&2
  exit 1
fi
echo "UILaunchScreen: present"

# Widgets can only use fonts declared in their own UIAppFonts (ADR-010): every declared font
# must be in the bundle, in the app and in each extension.
verify_fonts() {
  local bundle="$1"
  local count
  count="$(plutil -extract UIAppFonts raw -o - "$bundle/Info.plist" 2>/dev/null || echo 0)"
  if [ "$count" -eq 0 ]; then
    echo "error: $(basename "$bundle") declares no UIAppFonts" >&2
    exit 1
  fi
  for ((i = 0; i < count; i++)); do
    font="$(plutil -extract "UIAppFonts.$i" raw -o - "$bundle/Info.plist")"
    if [ ! -f "$bundle/$font" ]; then
      echo "error: $(basename "$bundle") declares $font but doesn't contain it" >&2
      exit 1
    fi
  done
  echo "Fonts in $(basename "$bundle"): $count, all present"
}
verify_fonts "$BUNDLE"
for appex in "$BUNDLE"/PlugIns/*.appex; do verify_fonts "$appex"; done

# Verify each signed bundle really carries the App Group entitlement (brief §9).
verify_entitlements() {
  local bundle="$1"
  local plist
  plist="$(codesign -d --entitlements :- "$bundle" 2>/dev/null || true)"
  echo "Entitlements of $(basename "$bundle"):"
  echo "$plist"
  if ! grep -q "com.apple.security.application-groups" <<<"$plist"; then
    echo "error: $(basename "$bundle") is missing the App Group entitlement" >&2
    exit 1
  fi
}
verify_entitlements "$BUNDLE"
for appex in "$BUNDLE"/PlugIns/*.appex; do verify_entitlements "$appex"; done

# No secrets may ship in the IPA (ADR-007).
if grep -rIlE --exclude='*.png' -e 'sk-ant-[A-Za-z0-9_-]{20,}' -e 'AIza[0-9A-Za-z_-]{35}' -e 'BEGIN [A-Z ]*PRIVATE KEY' "$BUNDLE" >/dev/null 2>&1; then
  echo "error: secret-like string found in the app bundle" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUT_ABS"
(cd "$WORK" && zip -qry "$OUT_ABS" Payload)
echo "Wrote $OUT_ABS ($(du -h "$OUT_ABS" | cut -f1))"
