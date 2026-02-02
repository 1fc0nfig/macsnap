#!/bin/bash
set -e

APP_NAME="MacSnap"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}"
APP_DIR="dist/${APP_NAME}.app"
DMG_FILE="dist/${DMG_NAME}.dmg"
BACKGROUND="Resources/dmg-background.png"
VOLUME_ICON="Sources/MacSnap/Resources/AppIcon.icns"

# Check if app exists
if [ ! -d "${APP_DIR}" ]; then
    echo "Error: ${APP_DIR} not found. Run ./scripts/build-app.sh first."
    exit 1
fi

echo "Creating DMG installer for ${APP_NAME} v${VERSION}..."

# Generate background if it doesn't exist
if [ ! -f "${BACKGROUND}" ]; then
    echo "Generating DMG background..."
    cd "$(dirname "$0")/.."
    swift scripts/generate-dmg-background.swift
fi

# Remove existing DMG
rm -f "${DMG_FILE}"

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg for professional DMG creation..."

    # Use create-dmg for professional look
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "${VOLUME_ICON}" \
        --background "${BACKGROUND}" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 140 180 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 500 180 \
        --no-internet-enable \
        "${DMG_FILE}" \
        "${APP_DIR}"
else
    echo "create-dmg not found, using basic hdiutil method..."
    echo "Install create-dmg for a professional DMG: brew install create-dmg"

    # Fallback to basic DMG creation
    DMG_DIR="dist/dmg"
    rm -rf "${DMG_DIR}"
    mkdir -p "${DMG_DIR}"

    cp -R "${APP_DIR}" "${DMG_DIR}/"
    ln -s /Applications "${DMG_DIR}/Applications"

    cat > "${DMG_DIR}/README.txt" << EOF
MacSnap - Screenshot Utility for macOS

Installation:
1. Drag MacSnap.app to the Applications folder
2. Launch MacSnap from Applications
3. Grant Screen Recording permission when prompted
4. Grant Accessibility permission for hotkeys when prompted

Default Hotkeys:
- Cmd+Shift+1: Full Screen
- Cmd+Shift+2: Area Selection
- Cmd+Shift+3: Window Capture
- Cmd+Shift+4: Custom Region

For more info, visit: https://github.com/1fc0nfig/macsnap
EOF

    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_DIR}" \
        -ov -format UDZO \
        "${DMG_FILE}"

    rm -rf "${DMG_DIR}"
fi

echo ""
echo "DMG created: ${DMG_FILE}"
echo "File size: $(du -h "${DMG_FILE}" | cut -f1)"
