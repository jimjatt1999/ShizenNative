#!/bin/bash

echo "Checking architecture support..."

# Check main binary
echo "Main binary:"
lipo -info build/Shizen.app/Contents/MacOS/Shizen

# Check FFmpeg
echo -e "\nFFmpeg binary:"
if [ -f build/Shizen.app/Contents/Resources/bin/ffmpeg ]; then
    lipo -info build/Shizen.app/Contents/Resources/bin/ffmpeg
else
    echo "FFmpeg not found"
fi

# Check yt-dlp differently since it's a Python script
echo -e "\nyt-dlp script:"
if [ -f build/Shizen.app/Contents/Resources/bin/yt-dlp ]; then
    file build/Shizen.app/Contents/Resources/bin/yt-dlp
else
    echo "yt-dlp not found"
fi

echo -e "\nChecking minimum macOS version..."
otool -l build/Shizen.app/Contents/MacOS/Shizen | grep -A 2 "LC_VERSION_MIN_MACOS" 