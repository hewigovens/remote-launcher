#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-package}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/Remote Launcher.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"

case "$MODE" in
  package|--notarize) ;;
  *) echo "usage: $0 [--notarize]" >&2; exit 2 ;;
esac

APP_OUTPUT_DIR="$RELEASE_DIR" BUILD_CONFIGURATION=release REQUIRE_DEVELOPER_ID=1 \
  "$ROOT_DIR/script/build_and_run.sh" --build-only

signature="$(codesign -dvv "$APP_BUNDLE" 2>&1)"
if ! grep -q '^Authority=Developer ID Application:' <<<"$signature"; then
  echo "The release must be signed with a Developer ID Application certificate." >&2
  exit 1
fi
if ! grep -q 'flags=.*runtime' <<<"$signature"; then
  echo "The release must enable Hardened Runtime." >&2
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
architecture="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/RemoteLauncher" | tr ' ' '-')"
ZIP_PATH="$RELEASE_DIR/RemoteLauncher-$version-macos-$architecture.zip"

archive_app() {
  # ditto can append to an existing archive, so always start with a fresh ZIP.
  rm -f "$ZIP_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
}

archive_app
if [[ "$MODE" == --notarize ]]; then
  result="$RELEASE_DIR/notarization.json"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 10m --output-format json >"$result"
  status="$(plutil -extract status raw -o - "$result")"
  submission_id="$(plutil -extract id raw -o - "$result")"
  xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE" \
    "$RELEASE_DIR/notarization-log.json"
  if [[ "$status" != Accepted ]]; then
    echo "Notarization status: $status. See $RELEASE_DIR/notarization-log.json." >&2
    exit 1
  fi
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
  archive_app
  echo "Notarized and stapled."
else
  echo "Developer ID signed; notarization has not been requested."
fi

codesign --verify --strict "$APP_BUNDLE"
(
  cd "$RELEASE_DIR"
  archive_name="$(basename "$ZIP_PATH")"
  shasum -a 256 "$archive_name" >"$archive_name.sha256"
)
echo "Archive: $ZIP_PATH"
