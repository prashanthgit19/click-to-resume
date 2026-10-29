#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(awk -F'"' '/MARKETING_VERSION/ { print $2; exit }' "$ROOT/project.yml")"
DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/DevSessionsRelease.XXXXXX")"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/DevSessionsStage.XXXXXX")"
trap 'rm -rf "$DERIVED" "$STAGING"' EXIT
DIST="$ROOT/dist"
APP="$DERIVED/Build/Products/Release/DevSessions.app"
DMG="$DIST/DevSessions-$VERSION.dmg"

rm -rf "$DIST"
mkdir -p "$DIST"

SIGN_ARGS=()
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  SIGN_ARGS+=("CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION")
fi

xcodebuild \
  -project "$ROOT/DevSessions.xcodeproj" \
  -scheme DevSessions \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  "${SIGN_ARGS[@]}" \
  build

ditto --norsrc --noextattr --noacl "$APP" "$STAGING/DevSessions.app"
ln -s /Applications "$STAGING/Applications"
cp -X "$ROOT/PRIVACY.md" "$STAGING/PRIVACY.md"

hdiutil create \
  -volname "DevSessions" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG"
fi

echo "Built $DMG"
