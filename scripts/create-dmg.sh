#!/bin/bash
set -e

APP_NAME="MacSnap"
VERSION="${1:-1.3.2}"
DMG_NAME="${APP_NAME}-${VERSION}"
APP_DIR="dist/${APP_NAME}.app"
DMG_FILE="dist/${DMG_NAME}.dmg"
DMG_STAGING="dist/dmg-staging"
BACKGROUND="Resources/dmg-background.png"
VOLUME_ICON="Sources/MacSnap/Resources/AppIcon.icns"
GETTING_STARTED="Resources/Getting Started.html"

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

# Remove existing DMG and staging
rm -f "${DMG_FILE}"
rm -rf "${DMG_STAGING}"

# Create staging directory with all DMG contents
echo "Preparing DMG contents..."
mkdir -p "${DMG_STAGING}"
cp -R "${APP_DIR}" "${DMG_STAGING}/"

# Copy Getting Started guide if it exists
if [ -f "${GETTING_STARTED}" ]; then
    cp "${GETTING_STARTED}" "${DMG_STAGING}/"
    echo "  Added Getting Started guide"
fi

# Check if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg for professional DMG creation..."

    # Use create-dmg for professional look
    if create-dmg \
        --volname "${APP_NAME}" \
        --volicon "${VOLUME_ICON}" \
        --background "${BACKGROUND}" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 140 240 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 500 240 \
        --icon "Getting Started.html" 320 100 \
        --no-internet-enable \
        "${DMG_FILE}" \
        "${DMG_STAGING}"
    then
        # Clean up staging
        rm -rf "${DMG_STAGING}"
    else
        echo "create-dmg failed, falling back to basic hdiutil method..."
        rm -f "${DMG_FILE}"
    fi
fi

if [ ! -f "${DMG_FILE}" ]; then
    if ! command -v create-dmg &> /dev/null; then
        echo "create-dmg not found, using basic hdiutil method..."
        echo "Install create-dmg for a professional DMG: brew install create-dmg"
    fi

    # Add Applications symlink and Getting Started to staging
    ln -s /Applications "${DMG_STAGING}/Applications"

    # Copy Getting Started guide if not already there
    if [ -f "${GETTING_STARTED}" ] && [ ! -f "${DMG_STAGING}/Getting Started.html" ]; then
        cp "${GETTING_STARTED}" "${DMG_STAGING}/"
    fi

    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_STAGING}" \
        -ov -format UDZO \
        "${DMG_FILE}"

    rm -rf "${DMG_STAGING}"
fi

echo ""
echo "DMG created: ${DMG_FILE}"
echo "File size: $(du -h "${DMG_FILE}" | cut -f1)"
