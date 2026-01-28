#!/bin/bash
set -e

APP_NAME="MacSnap"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}"
APP_DIR="dist/${APP_NAME}.app"
DMG_DIR="dist/dmg"
DMG_FILE="dist/${DMG_NAME}.dmg"

# Check if app exists
if [ ! -d "${APP_DIR}" ]; then
    echo "Error: ${APP_DIR} not found. Run ./scripts/build-app.sh first."
    exit 1
fi

echo "Creating DMG installer..."

# Clean up
rm -rf "${DMG_DIR}"
rm -f "${DMG_FILE}"

# Create DMG staging directory
mkdir -p "${DMG_DIR}"

# Copy app to DMG directory
cp -R "${APP_DIR}" "${DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_DIR}/Applications"

# Create README
cat > "${DMG_DIR}/README.txt" << EOF
MacSnap - Screenshot Utility for macOS

Installation:
1. Drag MacSnap.app to the Applications folder
2. Launch MacSnap from Applications
3. Grant Screen Recording permission when prompted
4. Grant Accessibility permission for hotkeys when prompted

CLI Installation (optional):
Copy 'macsnap-cli' from the dist folder to /usr/local/bin

Default Hotkeys:
- Cmd+Shift+1: Full Screen
- Cmd+Shift+2: Area Selection
- Cmd+Shift+3: Window Capture
- Cmd+Shift+4: Custom Region

For more info, visit: https://github.com/yourusername/macsnap
EOF

# Create the DMG
echo "Creating DMG file..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_FILE}"

# Clean up staging directory
rm -rf "${DMG_DIR}"

echo ""
echo "DMG created: ${DMG_FILE}"
echo ""
echo "File size: $(du -h "${DMG_FILE}" | cut -f1)"
