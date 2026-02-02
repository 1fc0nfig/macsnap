#!/bin/bash
set -e

# Configuration
APP_NAME="MacSnap"
BUNDLE_ID="com.macsnap.app"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"

echo "Building MacSnap.app..."

# Build release binary
swift build -c release

# Create app bundle structure
rm -rf "dist"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/MacSnap" "${APP_DIR}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>MacSnap needs screen recording permission to capture screenshots.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacSnap needs accessibility permission to register global hotkeys.</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Copy app icon
if [ -f "Sources/MacSnap/Resources/AppIcon.icns" ]; then
    cp "Sources/MacSnap/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
    echo "  Added AppIcon.icns"
fi

# Copy entitlements file for code signing
cp "Resources/macsnap.entitlements" "dist/MacSnap.entitlements"

# Code sign the app with hardened runtime (required for macOS Sonoma+ permissions)
# The --options runtime flag enables hardened runtime which is necessary for the app
# to appear in System Settings > Privacy & Security > Screen Recording
echo "  Signing app bundle with hardened runtime..."
codesign --force --deep --sign - --options runtime --entitlements "dist/MacSnap.entitlements" "${APP_DIR}" 2>/dev/null || {
    echo "  Warning: Code signing failed (this may affect permissions)"
    echo "  Try running: codesign --force --deep --sign - --options runtime --entitlements dist/MacSnap.entitlements dist/MacSnap.app"
}

# Copy CLI tool alongside
cp "${BUILD_DIR}/macsnap-cli" "dist/"

echo ""
echo "Build complete!"
echo ""
echo "App bundle: dist/${APP_NAME}.app"
echo "CLI tool:   dist/macsnap-cli"
echo ""
echo "To install:"
echo "  1. Copy ${APP_NAME}.app to /Applications"
echo "  2. Copy macsnap-cli to /usr/local/bin (optional)"
echo ""
echo "IMPORTANT: After installing, grant permissions in System Settings:"
echo "  - Privacy & Security > Screen Recording > Add MacSnap"
echo "  - Privacy & Security > Accessibility > Add MacSnap"
echo ""
echo "To create a DMG installer, run: ./scripts/create-dmg.sh"
