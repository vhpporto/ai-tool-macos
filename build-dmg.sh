#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Aura"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING_DIR=$(mktemp -d)

echo "→ Building release..."
swift build -c release 2>&1

echo "→ Packaging .app bundle..."
mkdir -p Aura.app/Contents/MacOS
mkdir -p Aura.app/Contents/Resources
cp .build/release/Aura Aura.app/Contents/MacOS/Aura
[ -f Aura.icns ] && cp Aura.icns Aura.app/Contents/Resources/Aura.icns
cat > Aura.app/Contents/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.aura.launcher</string>
    <key>CFBundleName</key><string>Aura</string>
    <key>CFBundleDisplayName</key><string>Aura</string>
    <key>CFBundleExecutable</key><string>Aura</string>
    <key>CFBundleIconFile</key><string>Aura</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "→ Signing..."
codesign --force --deep --sign - Aura.app

echo "→ Preparing DMG staging..."
cp -R Aura.app "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "→ Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    -imagekey zlib-level=9 \
    "$DMG_NAME"

rm -rf "$STAGING_DIR"

echo ""
echo "✓ Done: $(pwd)/$DMG_NAME"
