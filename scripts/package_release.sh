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
chmod 755 "$STAGING"

SIGN_ARGS=()
if [[ "${DEVELOPER_ID_APPLICATION:-}" == "-" ]]; then
  # Ad-hoc signing for public releases without a paid Apple Developer Program.
  SIGN_ARGS+=(
    "CODE_SIGN_IDENTITY=-"
    "CODE_SIGN_STYLE=Manual"
    "DEVELOPMENT_TEAM="
    "PROVISIONING_PROFILE_SPECIFIER="
  )
elif [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  SIGN_ARGS+=("CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION")
fi

xcodebuild \
  -project "$ROOT/DevSessions.xcodeproj" \
  -scheme DevSessions \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO" \
  "${SIGN_ARGS[@]}" \
  build

codesign --verify --deep --strict "$APP"

ARCHS="$(lipo -archs "$APP/Contents/MacOS/DevSessions")"
for arch in arm64 x86_64; do
  if [[ " $ARCHS " != *" $arch "* ]]; then
    echo "Missing $arch slice in $APP" >&2
    exit 1
  fi
done

if [[ ! -d "$APP/Contents/PlugIns/DevSessionsWidget.appex" ]]; then
  echo "Widget extension missing from $APP" >&2
  exit 1
fi

ditto --norsrc --noextattr --noacl "$APP" "$STAGING/DevSessions.app"
ln -s /Applications "$STAGING/Applications"
cp -X "$ROOT/PRIVACY.md" "$STAGING/PRIVACY.md"

hdiutil create \
  -volname "DevSessions" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

hdiutil verify "$DMG" >/dev/null

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" && "${DEVELOPER_ID_APPLICATION}" != "-" && -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG"
fi

(
  cd "$DIST"
  shasum -a 256 "$(basename "$DMG")" > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)

echo "Built $DMG"
echo "Wrote $DIST/SHA256SUMS"
