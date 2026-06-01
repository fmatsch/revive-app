#!/bin/bash
set -e

APP="Revive"
BUILD_DIR=".build/release"

echo "🔨 Baue $APP ..."
swift build -c release 2>&1

echo "📦 Erstelle App-Bundle ..."
BUNDLE="$APP.app/Contents"
rm -rf "$APP.app"
mkdir -p "$BUNDLE/MacOS" "$BUNDLE/Resources"

cp "$BUILD_DIR/$APP"         "$BUNDLE/MacOS/$APP"
cp "Resources/Info.plist"    "$BUNDLE/"

# Optional: copy app icon if generated
# cp "Resources/AppIcon.icns" "$BUNDLE/Resources/"

echo ""
echo "✅ Fertig: $APP.app"
echo ""
echo "Installieren mit:"
echo "  cp -r $APP.app /Applications/"
echo ""
echo "Oder direkt starten:"
echo "  open $APP.app"
