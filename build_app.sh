#!/bin/bash

# Set architecture flags for universal binary
export CFLAGS="-target arm64-apple-macos12.0 x86_64-apple-macos12.0"

# Build the Swift package as a universal binary
swift build \
    -c release \
    --arch arm64 \
    --arch x86_64

# Create app structure
mkdir -p build/Shizen.app/Contents/{MacOS,Resources,Frameworks}

# Copy the built executable
cp .build/apple/Products/Release/ShizenNative build/Shizen.app/Contents/MacOS/Shizen

# Copy Info.plist
cp Info.plist build/Shizen.app/Contents/Info.plist

# Bundle dependencies
./bundle_dependencies.sh

# Verify the build is universal
echo "Verifying universal binary..."
lipo -info build/Shizen.app/Contents/MacOS/Shizen

echo "App built at build/Shizen.app"