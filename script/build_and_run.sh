#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="RemoteLauncher"
DISPLAY_NAME="Remote Launcher"
BUNDLE_ID="dev.hewig.ScreenSharingLauncher"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${APP_OUTPUT_DIR:-$ROOT_DIR/dist}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-auto}"
APP_BUNDLE="$OUTPUT_DIR/$DISPLAY_NAME.app"
cd "$ROOT_DIR"

case "$MODE" in
  run|--debug|--logs|--telemetry|--verify|--build-only) ;;
  *) echo "usage: $0 [--debug|--logs|--telemetry|--verify|--build-only]" >&2; exit 2 ;;
esac
case "$BUILD_CONFIGURATION" in
  debug|release) ;;
  *) echo "BUILD_CONFIGURATION must be debug or release." >&2; exit 2 ;;
esac
# A debugger needs an unhardened local build, rather than the distribution signature.
if [[ "$MODE" == --debug && "$SIGNING_IDENTITY" == auto ]]; then
  SIGNING_IDENTITY="-"
fi

resolve_signing_identity() {
  if [[ "$SIGNING_IDENTITY" == auto ]]; then
    local identities
    identities="$(security find-identity -v -p codesigning | awk '/"Developer ID Application: / { print $2 }')"
    if [[ -z "$identities" ]]; then
      SIGNING_IDENTITY="-"
    elif [[ "$identities" == *$'\n'* ]]; then
      echo "Multiple Developer ID identities found. Set SIGNING_IDENTITY to the certificate name or SHA-1." >&2
      exit 1
    else
      SIGNING_IDENTITY="$identities"
    fi
  fi
  if [[ "${REQUIRE_DEVELOPER_ID:-0}" == 1 && "$SIGNING_IDENTITY" == - ]]; then
    echo "A Developer ID Application identity is required for distribution." >&2
    exit 1
  fi
}

resolve_signing_identity

if [[ "$MODE" != --build-only ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -x ScreenSharingLauncher >/dev/null 2>&1 || true
fi
swift build -c "$BUILD_CONFIGURATION" --product "$APP_NAME"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"
# Move the generated prototype bundle when upgrading to the new display name.
LEGACY_BUNDLE="$ROOT_DIR/dist/Screen Sharing Launcher.app"
if [[ "$OUTPUT_DIR" == "$ROOT_DIR/dist" && -d "$LEGACY_BUNDLE" && ! -e "$APP_BUNDLE" ]]; then
  mv "$LEGACY_BUNDLE" "$APP_BUNDLE"
fi
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
rm -f "$APP_BUNDLE/Contents/MacOS/ScreenSharingLauncher"

ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.png"
ICON_OUTPUT="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
if [[ ! -f "$ICON_OUTPUT" || "$ICON_SOURCE" -nt "$ICON_OUTPUT" ]]; then
  ICONSET="$ROOT_DIR/.build/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ICON_OUTPUT"
fi
cat >"$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
if [[ "$SIGNING_IDENTITY" == - ]]; then
  codesign --force --sign - "$APP_BUNDLE"
  echo "Signed ad hoc for local development."
else
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
  echo "Signed with Hardened Runtime and a secure timestamp."
fi
codesign --verify --strict "$APP_BUNDLE"

case "$MODE" in
  --build-only) echo "$APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs)
    /usr/bin/open "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    /usr/bin/open "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    /usr/bin/open "$APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$DISPLAY_NAME is running."
    ;;
  run) /usr/bin/open "$APP_BUNDLE" ;;
esac
