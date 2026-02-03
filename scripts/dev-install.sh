#!/bin/bash

# Dev Install Script for MacSnap
# Builds, installs, resets permissions, and launches the app for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="MacSnap.app"
APP_PATH="/Applications/$APP_NAME"
cd "$PROJECT_DIR"

echo "=== MacSnap Dev Install ==="
echo ""

# Step 1: Build the app (ad-hoc signing by default)
echo "[1/4] Building app (ad-hoc signing)..."
./scripts/build-app.sh

# Step 2: Kill any running instance
echo ""
echo "[2/4] Stopping any running MacSnap instance..."
killall MacSnap 2>/dev/null || true
sleep 0.5

# Step 3: Copy to /Applications
echo ""
echo "[3/4] Installing to /Applications..."
rm -rf "$APP_PATH"
cp -R dist/MacSnap.app "$APP_PATH"
echo "  Installed to $APP_PATH"

# Step 4: Reset TCC permissions
echo ""
echo "[4/4] Resetting permissions..."
tccutil reset ScreenCapture com.macsnap.app 2>/dev/null || tccutil reset ScreenCapture 2>/dev/null || true
tccutil reset Accessibility com.macsnap.app 2>/dev/null || tccutil reset Accessibility 2>/dev/null || true
echo "  Permissions reset (you'll need to grant them again)"

# Wait a moment for TCC to settle
sleep 1

# Launch the app
echo ""
echo "=== Done! ==="
echo ""
echo "Launching MacSnap..."
open "$APP_PATH"
