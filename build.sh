#!/bin/bash

# Build the Swift package
swift build -c release

# Create app bundle structure
APP_NAME="VoiceDictate"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist
cp "src/VoiceDictate/Sources/Info.plist" "$CONTENTS_DIR/"

# Create a default icon (you can replace this with your own icon later)
touch "$RESOURCES_DIR/AppIcon.icns"

# Make the app bundle executable
chmod +x "$MACOS_DIR/$APP_NAME"

echo "App bundle created at $BUNDLE_DIR" 