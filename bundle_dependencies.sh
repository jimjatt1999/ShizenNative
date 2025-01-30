#!/bin/bash
# bundle_dependencies.sh

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define app bundle location relative to script
APP_BUNDLE="$SCRIPT_DIR/build/Shizen.app"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

# Create directories
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$RESOURCES_DIR/bin"

# Install dependencies if not present
if ! command -v ffmpeg &> /dev/null; then
    echo "Installing FFmpeg..."
    brew install ffmpeg
fi

if ! command -v yt-dlp &> /dev/null; then
    echo "Installing yt-dlp..."
    pip install yt-dlp
fi

# Copy FFmpeg
FFMPEG_PATH=$(which ffmpeg)
if [ -f "$FFMPEG_PATH" ]; then
    cp "$FFMPEG_PATH" "$RESOURCES_DIR/bin/"
else
    echo "FFmpeg not found after installation attempt"
    exit 1
fi

# Copy yt-dlp
YTDLP_PATH=$(which yt-dlp)
if [ -f "$YTDLP_PATH" ]; then
    cp "$YTDLP_PATH" "$RESOURCES_DIR/bin/"
else
    echo "yt-dlp not found after installation attempt"
    exit 1
fi

# Copy Scripts directory
if [ -d "$SCRIPT_DIR/Scripts" ]; then
    cp -R "$SCRIPT_DIR/Scripts" "$RESOURCES_DIR/"
fi

# Set up correct permissions
chmod +x "$RESOURCES_DIR/bin/"*

echo "Dependencies bundled successfully to $APP_BUNDLE"
