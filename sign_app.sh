#!/bin/bash

# Create a self-signed certificate
CERT_NAME="ShizenSelfSigned"

# Check if certificate already exists
if ! security find-certificate -c "$CERT_NAME" login.keychain >/dev/null 2>&1; then
    echo "Creating self-signed certificate..."
    security create-keychain -p "" build.keychain
    security default-keychain -s build.keychain
    
    # Create certificate
    openssl req -x509 -newkey rsa:2048 -keyout temp.key -out temp.cer -days 365 -nodes -subj "/CN=$CERT_NAME"
    
    # Import certificate
    security import temp.cer -k build.keychain
    security import temp.key -k build.keychain
    
    # Clean up
    rm temp.cer temp.key
fi

# Sign the app
echo "Signing app..."
codesign --force --deep --sign "$CERT_NAME" "build/Shizen.app"

echo "App signed with self-signed certificate" 