#!/usr/bin/env bash
# Capture screenshots of every screen on iPad Pro 13-inch (M4) and iPhone 16 Pro.
# Usage: bash scripts/screenshots.sh [all|ipad|iphone]
# Output: screenshots/<device>/<NN>_<screen>.png

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.immersed"
SCREENSHOTS_DIR="$PROJECT_ROOT/screenshots"
INFO_PLIST="$PROJECT_ROOT/ios/Runner/Info.plist"
INFO_PLIST_BACKUP="$PROJECT_ROOT/.context/Info.plist.screenshots.backup"
MODE="${1:-all}"

# The integration test reads this file via rootBundle. We copy it in before
# running flutter drive so it gets bundled into the .app, then remove it
# afterwards to keep the repo clean.
SAMPLE_DST="$PROJECT_ROOT/assets/test/sample.epub"

cleanup() {
  rm -f "$SAMPLE_DST"
  if [ -f "$INFO_PLIST_BACKUP" ]; then
    cp "$INFO_PLIST_BACKUP" "$INFO_PLIST"
    rm -f "$INFO_PLIST_BACKUP"
  fi
}
trap cleanup EXIT

# 1. Locate the source EPUB (any file in the project root that starts with
#    "Project Hail Mary" and ends with .epub).
SAMPLE_SRC=$(find "$PROJECT_ROOT" -maxdepth 1 -type f -iname "Project Hail Mary*.epub" | head -n 1 || true)
if [ -z "$SAMPLE_SRC" ]; then
  echo "ERROR: no 'Project Hail Mary*.epub' found in $PROJECT_ROOT"
  echo "       Place an EPUB at the repo root or update SAMPLE_SRC in this script."
  exit 1
fi
echo "Using sample EPUB: $(basename "$SAMPLE_SRC")"
cp "$SAMPLE_SRC" "$SAMPLE_DST"

# Screenshot-only iPad landscape builds need full-screen mode enabled; otherwise
# iPadOS keeps the app in a windowing mode that rejects orientation changes.
cp "$INFO_PLIST" "$INFO_PLIST_BACKUP"
/usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen true" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool true" "$INFO_PLIST"

# 2. Reset output directory.
rm -rf "$SCREENSHOTS_DIR"
mkdir -p "$SCREENSHOTS_DIR"

# 3. Resolve a UDID from a device name. Prefers booted matches.
resolve_udid() {
  local device_name="$1"
  xcrun simctl list devices available \
    | grep -F "$device_name" \
    | head -n 1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
}

run_one_device() {
  local label="$1"
  local device_name="$2"
  local out_subdir="$3"
  local orientation="${4:-portrait}"

  echo ""
  echo "=========================================="
  echo "[$label] $device_name"
  echo "=========================================="

  local udid
  udid=$(resolve_udid "$device_name")
  if [ -z "$udid" ]; then
    echo "ERROR: could not find an available simulator named '$device_name'."
    echo "       Run 'xcrun simctl list devices available' to inspect."
    return 1
  fi
  echo "UDID: $udid"

  # Force the Simulator window orientation by editing its prefs BEFORE the app
  # reads them. SystemChrome.setPreferredOrientations alone does not actually
  # rotate the iOS simulator, so we set the persisted geometry instead.
  local prefs="$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
  local sim_orient
  local sim_angle
  if [ "$orientation" = "landscape" ]; then
    sim_orient="LandscapeLeft"
    sim_angle="-270"
  else
    sim_orient="Portrait"
    sim_angle="0"
  fi
  echo "-> set simulator orientation: $sim_orient"
  osascript -e 'tell application "Simulator" to quit' 2>/dev/null || true
  sleep 1
  /usr/libexec/PlistBuddy -c "Set :DevicePreferences:$udid:SimulatorWindowOrientation $sim_orient" "$prefs" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :DevicePreferences:$udid:SimulatorWindowOrientation string $sim_orient" "$prefs"
  /usr/libexec/PlistBuddy -c "Set :DevicePreferences:$udid:SimulatorWindowRotationAngle $sim_angle" "$prefs" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :DevicePreferences:$udid:SimulatorWindowRotationAngle integer $sim_angle" "$prefs"

  echo "-> boot simulator"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  open -a Simulator
  # Simulator.app and SpringBoard both need a few extra seconds after boot.
  sleep 8

  echo "-> uninstall previous app data ($BUNDLE_ID)"
  xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true

  local out_dir="$SCREENSHOTS_DIR/$out_subdir"
  mkdir -p "$out_dir"

  echo "-> flutter drive (screenshots → $out_dir, orientation=$orientation)"
  (
    cd "$PROJECT_ROOT"
    SCREENSHOT_DIR="$out_dir" flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/screenshots_test.dart \
      --dart-define=SCREENSHOT_ORIENTATION="$orientation" \
      -d "$udid"
  )

  echo "-> shutdown simulator"
  xcrun simctl shutdown "$udid" 2>/dev/null || true

  echo "[$label] done. Files:"
  ls -1 "$out_dir" || true
}

case "$MODE" in
  all)
    run_one_device "iPad" "iPad Pro 13-inch (M4)" "ipad-pro-13" "landscape"
    run_one_device "iPhone" "iPhone 16 Pro" "iphone-16-pro" "portrait"
    ;;
  ipad)
    run_one_device "iPad" "iPad Pro 13-inch (M4)" "ipad-pro-13" "landscape"
    ;;
  iphone)
    run_one_device "iPhone" "iPhone 16 Pro" "iphone-16-pro" "portrait"
    ;;
  *)
    echo "ERROR: unknown mode '$MODE'. Use: all, ipad, or iphone."
    exit 1
    ;;
esac

echo ""
echo "Done. Screenshots:"
if [ -d "$SCREENSHOTS_DIR/ipad-pro-13" ]; then
  echo "  $SCREENSHOTS_DIR/ipad-pro-13/"
fi
if [ -d "$SCREENSHOTS_DIR/iphone-16-pro" ]; then
  echo "  $SCREENSHOTS_DIR/iphone-16-pro/"
fi
