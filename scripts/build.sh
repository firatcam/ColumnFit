#!/bin/bash
# Builds ColumnFit.app (universal: Apple Silicon + Intel, macOS 13+).
#
#   ./scripts/build.sh                      -> ad-hoc signed build (works locally; Gatekeeper asks on other Macs)
#
# Developer ID signing + notarization (needs a paid Apple Developer account):
#
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   APPLE_ID="you@example.com" APPLE_TEAM_ID="TEAMID" APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
#   ./scripts/build.sh
#
#   (or, instead of the three APPLE_* variables, a stored notarytool profile:  NOTARY_PROFILE="my-profile")
#
# Optional: VERSION=1.3.0   BUNDLE_ID=io.github.yourname.ColumnFit
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ColumnFit"
VERSION="${VERSION:-1.3.0}"
BUNDLE_ID="${BUNDLE_ID:-io.github.columnfit.ColumnFit}"
IDENTITY="${CODESIGN_IDENTITY:--}"          # "-" = ad-hoc
OUT="build"
APP="$OUT/$APP_NAME.app"
ZIP="$OUT/$APP_NAME-$VERSION.zip"

rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Building universal binary (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

echo "▸ Assembling bundle…"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" \
    Resources/Info.plist > "$APP/Contents/Info.plist"

if [ -d Resources/AppIcon.iconset ] && command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
elif [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "▸ Signing with identity: $IDENTITY"
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

if [ "$IDENTITY" != "-" ]; then
    NOTARIZE=""
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        NOTARIZE="profile"
    elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
        NOTARIZE="credentials"
    fi

    if [ -n "$NOTARIZE" ]; then
        echo "▸ Notarizing (this can take a few minutes)…"
        ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
        if [ "$NOTARIZE" = "profile" ]; then
            xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
        else
            xcrun notarytool submit "$OUT/notarize.zip" \
                --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
        fi
        xcrun stapler staple "$APP"
        rm -f "$OUT/notarize.zip"
    else
        echo "⚠ Signed, but not notarized (no notarization credentials given)."
    fi
fi

echo "▸ Creating $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "✔ Done: $APP"
echo "  Run:   open \"$APP\""
