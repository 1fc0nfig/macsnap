#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Configuration
APP_NAME="MacSnap"
BUNDLE_ID="com.macsnap.app"
VERSION="1.3.2"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"
SIGN_IDENTITY="${MACSNAP_SIGN_IDENTITY:-${SIGN_IDENTITY:-}}"
MODULE_CACHE="${ROOT_DIR}/.build/module-cache"
CLANG_CACHE="${ROOT_DIR}/.build/clang-module-cache"

mkdir -p "$MODULE_CACHE" "$CLANG_CACHE"

echo "Building MacSnap.app..."

# Build release binary
HOME="$ROOT_DIR" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
swift build --disable-sandbox -c release

# Create app bundle structure
rm -rf "dist"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/MacSnap" "${APP_DIR}/Contents/MacOS/"
cp "${BUILD_DIR}/macsnap-cli" "${APP_DIR}/Contents/MacOS/"
chmod +x "${APP_DIR}/Contents/MacOS/MacSnap" "${APP_DIR}/Contents/MacOS/macsnap-cli"

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
    <string>${VERSION}</string>
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

# Always use ad-hoc signing (works without Apple Developer account)
# This avoids certificate chain issues with Apple Development certificates
SIGN_IDENTITY="-"
echo "  Using signing identity: ${SIGN_IDENTITY}"

# Code sign the app with hardened runtime
echo "  Signing app bundle..."
codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime --entitlements "dist/MacSnap.entitlements" "${APP_DIR}"

# Verify signature
if codesign -vvv --deep --strict "${APP_DIR}" >/dev/null 2>&1; then
    echo "  App signed successfully"
else
    echo "  Warning: Signature verification failed"
fi

# Copy CLI tool alongside for standalone distribution as well
cp "${BUILD_DIR}/macsnap-cli" "dist/"

echo ""
echo "Build complete!"
echo ""
echo "App bundle: dist/${APP_NAME}.app"
echo "CLI tool:   dist/macsnap-cli"
echo ""
echo "To install:"
echo "  1. Copy ${APP_NAME}.app to /Applications"
echo "  2. (Optional) Link CLI:"
echo "     ln -sf /Applications/${APP_NAME}.app/Contents/MacOS/macsnap-cli /usr/local/bin/macsnap-cli"
echo ""
echo "IMPORTANT: After installing, grant permissions in System Settings:"
echo "  - Privacy & Security > Screen Recording > Add MacSnap"
echo "  - Privacy & Security > Accessibility > Add MacSnap"
echo ""
echo "To create a DMG installer, run: ./scripts/create-dmg.sh"
