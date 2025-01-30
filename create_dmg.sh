#!/bin/bash

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "Installing create-dmg..."
    brew install create-dmg
fi

# Sign the app first
./sign_app.sh

# Set variables
APP_NAME="Shizen"
DMG_NAME="${APP_NAME}_v1.0.dmg"
APP_PATH="build/${APP_NAME}.app"
DMG_PATH="build/${DMG_NAME}"
VOLUME_NAME="${APP_NAME} Installer"

# Ensure build directory exists
mkdir -p build

# Create DMG
create-dmg \
    --volname "${VOLUME_NAME}" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 200 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 600 185 \
    --no-internet-enable \
    "${DMG_PATH}" \
    "${APP_PATH}"

# Sign the DMG as well
codesign --force --sign "ShizenSelfSigned" "${DMG_PATH}"

echo "DMG created and signed at ${DMG_PATH}" 