#!/bin/bash
set -e

# Export PATH to use Homebrew Swift
export PATH="/opt/homebrew/opt/swift/bin:$PATH"

# Build the project in release mode
echo "Building VoiceDictate..."
swift build -c release

# Create app folder structure
echo "Creating app bundle..."
APP_PATH="./build/VoiceDictate.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# Copy executable
cp .build/release/VoiceDictate "$MACOS_PATH/"

# Copy Info.plist
cp src/VoiceDictate/Sources/Info.plist "$CONTENTS_PATH/"

# Create a basic icon file (empty for now)
touch "$RESOURCES_PATH/AppIcon.icns"

# Make executable
chmod +x "$MACOS_PATH/VoiceDictate"

echo "App bundle created at $APP_PATH"
echo "To run the app: open $APP_PATH" 