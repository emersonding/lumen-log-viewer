#!/bin/bash
set -e

echo "🔨 Building LogViewer..."

# Build the executable
swift build -c release

# Create .app bundle structure
APP_NAME="LogViewer.app"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME"

echo "📦 Creating app bundle..."

# Clean and create directories
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/LogViewer "$APP_DIR/Contents/MacOS/LogViewer"

# Copy Info.plist
cp Info.plist "$APP_DIR/Contents/Info.plist"

# Set executable permissions
chmod +x "$APP_DIR/Contents/MacOS/LogViewer"

echo "✅ App bundle created at: $APP_DIR"
echo ""
echo "To run the app:"
echo "  open $APP_DIR"
echo ""
echo "To install it to Applications:"
echo "  cp -r $APP_DIR /Applications/"
