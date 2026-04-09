#!/usr/bin/env bash
# Setup script: install all project dependencies from scratch.
# Run this after cloning, switching worktree, or running archive.sh.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Setting up project: $PROJECT_ROOT"
echo ""

# 1. Flutter pub get
echo "=> flutter pub get"
(cd "$PROJECT_ROOT" && flutter pub get)

# 2. iOS: pod install (non-fatal — may fail due to network/proxy issues)
if [ -f "$PROJECT_ROOT/ios/Podfile" ]; then
    echo ""
    echo "=> pod install (ios/)"
    (cd "$PROJECT_ROOT/ios" && LANG=en_US.UTF-8 pod install) || echo "WARNING: pod install (ios/) failed — you can retry manually later"
fi

# 3. macOS: pod install (non-fatal — may fail due to network/proxy issues)
if [ -f "$PROJECT_ROOT/macos/Podfile" ]; then
    echo ""
    echo "=> pod install (macos/)"
    (cd "$PROJECT_ROOT/macos" && LANG=en_US.UTF-8 pod install) || echo "WARNING: pod install (macos/) failed — you can retry manually later"
fi

# 4. Rust: cargo build
if [ -f "$PROJECT_ROOT/rust/Cargo.toml" ]; then
    echo ""
    echo "=> cargo build (rust/)"
    (cd "$PROJECT_ROOT/rust" && cargo build)
fi

# 5. Node modules (tool/)
if [ -f "$PROJECT_ROOT/tool/reader_render_diff/package.json" ]; then
    echo ""
    echo "=> npm install (tool/reader_render_diff/)"
    (cd "$PROJECT_ROOT/tool/reader_render_diff" && npm install)
fi

echo ""
echo "Done! All dependencies installed."
