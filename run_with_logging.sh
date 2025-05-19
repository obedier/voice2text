#!/bin/bash

echo "🔨 Building VoiceDictate..."

# Enable verbose output
set -x

# Build the Swift package
swift build -c debug -v

if [ $? -eq 0 ]; then
    echo "✅ Build successful"
    echo "📦 Creating app bundle..."
    
    # Create app bundle structure
    APP_NAME="VoiceDictate"
    BUNDLE_DIR="$APP_NAME.app"
    CONTENTS_DIR="$BUNDLE_DIR/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"

    # Create necessary directories
    rm -rf "$BUNDLE_DIR"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    # Copy the executable
    cp ".build/debug/$APP_NAME" "$MACOS_DIR/"

    # Copy Info.plist
    cp "src/VoiceDictate/Sources/Info.plist" "$CONTENTS_DIR/"

    # Make the app bundle executable
    chmod +x "$MACOS_DIR/$APP_NAME"

    echo "🚀 Launching VoiceDictate..."
    echo "----------------------------------------"
    
    # Kill any existing instances
    pkill -f VoiceDictate || true
    
    # Launch the app with more verbose output
    OBJC_DEBUG_MISSING_SELECTOR=YES NSZombieEnabled=YES "$MACOS_DIR/$APP_NAME" 2>&1 | tee voice_dictate.log
else
    echo "❌ Build failed"
    exit 1
fi 