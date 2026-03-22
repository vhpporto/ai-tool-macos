#!/bin/bash
set -e
cd "$(dirname "$0")"

CERT_NAME="Aura Dev Certificate"

# Create a self-signed certificate once if it doesn't exist
if ! security find-certificate -c "$CERT_NAME" ~/Library/Keychains/login.keychain-db &>/dev/null; then
    echo "Creating self-signed certificate for consistent code signing..."
    # Generate key + self-signed cert valid for 10 years
    security create-keychain-certificate \
        -c "$CERT_NAME" \
        -k ~/Library/Keychains/login.keychain-db 2>/dev/null || true

    # Fallback: use openssl + security import
    TMPDIR_CERT=$(mktemp -d)
    openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR_CERT/key.pem" \
        -out "$TMPDIR_CERT/cert.pem" -days 3650 -nodes \
        -subj "/CN=$CERT_NAME/O=Aura/C=BR" 2>/dev/null
    openssl pkcs12 -export -out "$TMPDIR_CERT/aura.p12" \
        -inkey "$TMPDIR_CERT/key.pem" -in "$TMPDIR_CERT/cert.pem" \
        -passout pass: 2>/dev/null
    security import "$TMPDIR_CERT/aura.p12" \
        -k ~/Library/Keychains/login.keychain-db \
        -P "" -T /usr/bin/codesign &>/dev/null || true
    rm -rf "$TMPDIR_CERT"
    echo "Certificate created."
fi

echo "Building Aura..."
swift build 2>&1

echo "Packaging .app bundle..."
mkdir -p Aura.app/Contents/MacOS
mkdir -p Aura.app/Contents/Resources
cp .build/debug/Aura Aura.app/Contents/MacOS/Aura
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

echo "Signing Aura.app..."
codesign --force --deep --sign "$CERT_NAME" Aura.app 2>/dev/null || \
    codesign --force --deep --sign - Aura.app

echo "Launching Aura..."
open Aura.app
