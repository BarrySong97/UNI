#!/usr/bin/env bash
# Archive script: clean up all build artifacts and downloaded dependencies
# Run this to reclaim disk space in worktrees you no longer actively develop in.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Archiving project: $PROJECT_ROOT"
echo ""

# 1. Flutter clean (removes build/ and .dart_tool/)
echo "=> flutter clean"
(cd "$PROJECT_ROOT" && flutter clean)

# 2. Remove pub cache (.pub-cache/, .dart_tool/)
echo ""
echo "=> Removing .dart_tool/"
rm -rf "$PROJECT_ROOT/.dart_tool"

# 3. iOS: remove Pods and build artifacts
echo ""
echo "=> Cleaning iOS dependencies (Pods)"
rm -rf "$PROJECT_ROOT/ios/Pods"
rm -rf "$PROJECT_ROOT/ios/.symlinks"
rm -rf "$PROJECT_ROOT/ios/Flutter/Flutter.framework"
rm -rf "$PROJECT_ROOT/ios/Flutter/Flutter.podspec"
rm -rf "$PROJECT_ROOT/ios/Flutter/App.framework"
rm -rf "$PROJECT_ROOT/ios/Flutter/engine"
rm -rf "$PROJECT_ROOT/ios/Flutter/Generated.xcconfig"
rm -rf "$PROJECT_ROOT/ios/Flutter/flutter_export_environment.sh"

echo "=> Cleaning macOS dependencies (Pods)"
rm -rf "$PROJECT_ROOT/macos/Pods"
rm -rf "$PROJECT_ROOT/macos/.symlinks"
rm -rf "$PROJECT_ROOT/macos/Flutter/Flutter.framework"
rm -rf "$PROJECT_ROOT/macos/Flutter/GeneratedPluginRegistrant.swift"
rm -rf "$PROJECT_ROOT/macos/Flutter/ephemeral"

# 4. Android: clean Gradle cache and build
echo ""
echo "=> Cleaning Android build"
rm -rf "$PROJECT_ROOT/android/.gradle"
rm -rf "$PROJECT_ROOT/android/app/build"
rm -rf "$PROJECT_ROOT/android/build"
rm -rf "$PROJECT_ROOT/build"

# 5. Rust: cargo clean
if [ -f "$PROJECT_ROOT/rust/Cargo.toml" ]; then
    echo ""
    echo "=> cargo clean (rust/)"
    (cd "$PROJECT_ROOT/rust" && cargo clean 2>/dev/null || true)
fi

# 6. Node modules (tool/)
if [ -d "$PROJECT_ROOT/tool/reader_render_diff/node_modules" ]; then
    echo ""
    echo "=> Removing tool/reader_render_diff/node_modules/"
    rm -rf "$PROJECT_ROOT/tool/reader_render_diff/node_modules"
fi

# 7. Remove generated Flutter plugin files
echo ""
echo "=> Removing generated Flutter plugin files"
rm -f "$PROJECT_ROOT/.flutter-plugins"
rm -f "$PROJECT_ROOT/.flutter-plugins-dependencies"

# 8. Linux/Windows build artifacts
rm -rf "$PROJECT_ROOT/linux/flutter/ephemeral"
rm -rf "$PROJECT_ROOT/windows/flutter/ephemeral"

echo ""
echo "Done! Project archived and cleaned."
