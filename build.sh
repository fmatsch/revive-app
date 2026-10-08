#!/bin/bash
set -e

APP="Revive"
BUILD_DIR=".build/release"

echo "🔨 Baue $APP ..."
swift build -c release 2>&1

echo "🎨 Icon generieren ..."
swift scripts/make_icon.swift 2>&1
iconutil -c icns scripts/Revive.iconset -o Resources/AppIcon.icns

echo "📦 Erstelle App-Bundle ..."
BUNDLE="$APP.app/Contents"
rm -rf "$APP.app"
mkdir -p "$BUNDLE/MacOS" "$BUNDLE/Resources"

cp "$BUILD_DIR/$APP"          "$BUNDLE/MacOS/$APP"
cp "Resources/Info.plist"     "$BUNDLE/"
cp "Resources/AppIcon.icns"   "$BUNDLE/Resources/"

echo "🔏 Code-Signing (ad-hoc) ..."
codesign --force --deep --sign - "$APP.app"

echo ""
echo "✅ Fertig: $APP.app"
echo ""
echo "Installieren mit:"
echo "  cp -r $APP.app /Applications/"
echo ""
echo "Oder direkt starten:"
echo "  open $APP.app"
