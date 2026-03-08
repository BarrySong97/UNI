#!/bin/bash

# Integration Test Runner for Flureadium
#
# Runs integration tests for Android, iOS, and Web sequentially.
# Continues on test failure — reports a summary at the end.
#
# Usage:
#   ./scripts/run_integration_tests.sh [options]
#
# Options:
#   --android-device <id>   Android device/emulator ID (prompted if omitted)
#   --ios-device <id>       iOS device/simulator ID (prompted if omitted)
#   --skip-android          Skip Android tests
#   --skip-ios              Skip iOS tests
#   --skip-web              Skip Web tests
#   --verbose               Show full flutter output (printed after each test)
#   --help                  Show this help and exit
#
# Web prerequisites:
#   ChromeDriver is required for web tests. The script will attempt to start it
#   automatically (using the system `chromedriver` binary or `npx chromedriver`).
#   If auto-start fails you will be prompted with manual instructions.
#
# Android note:
#   Runs the full suite including @native audiobook tests.
#   CI excludes @native via --exclude-tags native because GitHub-hosted
#   emulators have unreliable audio; local runs include them.
#
# iOS note:
#   Audiobook tests (tagged @native) are included in the iOS suite.
#   They require a connected device or booted simulator (iOS >= 16).

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$PLUGIN_DIR/example"
LOG_BASE="$PLUGIN_DIR/test_logs"

# ── Defaults ──────────────────────────────────────────────────────────────────
VERBOSE=false
SKIP_ANDROID=false
SKIP_IOS=false
SKIP_WEB=false
ANDROID_DEVICE=""
IOS_DEVICE=""
SELECTED_DEVICE=""      # written by select_device()
CHROMEDRIVER_PID=""     # set when this script starts ChromeDriver
ALL_DEVICES_STRIPPED="" # set once by the device scan; reused by both select_device calls

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  sed -n '3,36p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --android-device) ANDROID_DEVICE="$2"; shift 2 ;;
    --ios-device)     IOS_DEVICE="$2";     shift 2 ;;
    --skip-android)   SKIP_ANDROID=true;   shift ;;
    --skip-ios)       SKIP_IOS=true;       shift ;;
    --skip-web)       SKIP_WEB=true;       shift ;;
    --verbose)        VERBOSE=true;        shift ;;
    --help|-h)        usage ;;
    *)
      printf "${RED}Unknown option: %s${NC}\n" "$1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# ── Log directory ─────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$LOG_BASE/run_$TIMESTAMP"
mkdir -p "$LOG_DIR"
SUMMARY_LOG="$LOG_DIR/summary.log"

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
  if [ -n "$CHROMEDRIVER_PID" ]; then
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ── Logging helpers ───────────────────────────────────────────────────────────
log() {
  echo -e "$1" | tee -a "$SUMMARY_LOG"
}

# ── Device selection ──────────────────────────────────────────────────────────
# Filters ALL_DEVICES_STRIPPED by <pattern>, auto-selects if only one match,
# prompts if multiple. Sets SELECTED_DEVICE; returns 1 if none found.
select_device() {
  local label="$1"
  local pattern="$2"
  SELECTED_DEVICE=""

  local -a lines=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if echo "$line" | grep -qE "$pattern"; then
      lines+=("$line")
    fi
  done <<< "$ALL_DEVICES_STRIPPED"

  if [[ ${#lines[@]} -eq 0 ]]; then
    log "  ${RED}No $label device or emulator/simulator found.${NC}"
    log "  Connect a device or start an emulator/simulator, then re-run."
    return 1
  fi

  if [[ ${#lines[@]} -eq 1 ]]; then
    log "  $label: ${lines[0]}"
    SELECTED_DEVICE=$(echo "${lines[0]}" | awk -F' • ' '{print $2}' | xargs)
    return 0
  fi

  log "  Multiple $label devices found:"
  local i
  for i in "${!lines[@]}"; do
    log "    $((i+1))) ${lines[$i]}"
  done

  local choice
  while true; do
    printf "\n  Select $label device [1-%d]: " "${#lines[@]}" >&2
    read -r choice </dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#lines[@]} )); then
      break
    fi
    printf "  Enter a number between 1 and %d.\n" "${#lines[@]}" >&2
  done

  local selected="${lines[$((choice-1))]}"
  SELECTED_DEVICE=$(echo "$selected" | awk -F' • ' '{print $2}' | xargs)
}

# ── Test runner ───────────────────────────────────────────────────────────────
# Runs the given command, captures output to <logfile>, and returns the exit code.
# On failure (or --verbose), prints the captured output.
run_test() {
  local label="$1"
  local logfile="$2"
  shift 2

  log ""
  log "${BLUE}▶  $label${NC}"

  local exit_code=0
  "$@" > "$logfile" 2>&1 || exit_code=$?

  if [ "$VERBOSE" = true ]; then
    cat "$logfile" | tee -a "$SUMMARY_LOG"
  fi

  if [ $exit_code -eq 0 ]; then
    log "${GREEN}   passed${NC}"
    return 0
  else
    log "${RED}   FAILED${NC}"
    if [ "$VERBOSE" = false ]; then
      log "   Output (${logfile}):"
      cat "$logfile" | tee -a "$SUMMARY_LOG"
    fi
    return 1
  fi
}

# ── ChromeDriver helpers ──────────────────────────────────────────────────────

# Returns the Chrome major version number, or empty string if Chrome not found.
detect_chrome_major() {
  local ver=""
  if [[ "$(uname)" == "Darwin" ]]; then
    ver=$("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --version 2>/dev/null || true)
  fi
  if [ -z "$ver" ]; then
    ver=$(google-chrome --version 2>/dev/null || \
          chromium-browser --version 2>/dev/null || \
          chromium --version 2>/dev/null || true)
  fi
  echo "$ver" | grep -oE '[0-9]+' | head -1
}

# Polls port 4444 until ChromeDriver responds or <timeout> seconds elapse.
wait_for_chromedriver() {
  local timeout="$1"
  local elapsed=0
  while (( elapsed < timeout )); do
    if curl -s --max-time 1 http://localhost:4444/status > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
    (( elapsed++ )) || true
  done
  return 1
}

# Tries to start ChromeDriver in the background. Sets CHROMEDRIVER_PID on success.
# Returns 0 if ChromeDriver is ready, 1 if all attempts failed.
# When chrome_major is known, npx chromedriver@<major> is tried first to guarantee
# version alignment. The system binary is a fallback for when npx is unavailable.
try_start_chromedriver() {
  local chrome_major="$1"

  log "${YELLOW}Attempting to start ChromeDriver automatically...${NC}"

  # 1. npx chromedriver@<major> — version-matched, preferred when Chrome is detected
  if command -v npx > /dev/null 2>&1 && [ -n "$chrome_major" ]; then
    log "  Trying: npx chromedriver@${chrome_major} --port=4444"
    npx "chromedriver@${chrome_major}" --port=4444 > "$LOG_DIR/chromedriver.log" 2>&1 &
    CHROMEDRIVER_PID=$!
    if wait_for_chromedriver 15; then
      log "${GREEN}  ChromeDriver started via npx (PID $CHROMEDRIVER_PID).${NC}"
      return 0
    fi
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
    CHROMEDRIVER_PID=""
  fi

  # 2. System chromedriver binary — fallback when npx is unavailable or Chrome undetected
  if command -v chromedriver > /dev/null 2>&1; then
    log "  Trying system chromedriver..."
    chromedriver --port=4444 > "$LOG_DIR/chromedriver.log" 2>&1 &
    CHROMEDRIVER_PID=$!
    if wait_for_chromedriver 5; then
      log "${GREEN}  ChromeDriver started (system binary, PID $CHROMEDRIVER_PID).${NC}"
      return 0
    fi
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
    CHROMEDRIVER_PID=""
  fi

  return 1
}

# ── Resolve devices ───────────────────────────────────────────────────────────
ANDROID_SKIP_REASON=""
IOS_SKIP_REASON=""

NEEDS_SCAN=false
{ [ "$SKIP_ANDROID" = false ] && [ -z "$ANDROID_DEVICE" ]; } && NEEDS_SCAN=true
{ [ "$SKIP_IOS" = false ]     && [ -z "$IOS_DEVICE" ]; }     && NEEDS_SCAN=true

if [ "$NEEDS_SCAN" = true ]; then
  log ""
  log "${YELLOW}Scanning available devices...${NC}"
  local_raw=$(flutter devices 2>/dev/null || true)
  ALL_DEVICES_STRIPPED=$(echo "$local_raw" | sed 's/\x1b\[[0-9;]*[mK]//g')
fi

if [ "$SKIP_ANDROID" = false ] && [ -z "$ANDROID_DEVICE" ]; then
  if ! select_device "Android" "android"; then
    SKIP_ANDROID=true
    ANDROID_SKIP_REASON="no device found"
  else
    ANDROID_DEVICE="$SELECTED_DEVICE"
  fi
fi

if [ "$SKIP_IOS" = false ] && [ -z "$IOS_DEVICE" ]; then
  if ! select_device "iOS" "(• ios |[Ii][Pp]hone|[Ii][Pp]ad)"; then
    SKIP_IOS=true
    IOS_SKIP_REASON="no device found"
  else
    IOS_DEVICE="$SELECTED_DEVICE"
  fi
fi

# ── Ensure ChromeDriver is available for web ──────────────────────────────────
if [ "$SKIP_WEB" = false ]; then
  if ! curl -s --max-time 2 http://localhost:4444/status > /dev/null 2>&1; then
    log ""
    CHROME_MAJOR=$(detect_chrome_major)
    if ! try_start_chromedriver "$CHROME_MAJOR"; then
      log ""
      log "${YELLOW}ChromeDriver could not be started automatically.${NC}"
      log "Start it manually in a separate terminal, then re-run this script:"
      if [ -n "$CHROME_MAJOR" ]; then
        log "  npx chromedriver@${CHROME_MAJOR} --port=4444"
      else
        log "  npx chromedriver@<your-chrome-major-version> --port=4444"
        log "  (Chrome not found on this machine; install Chrome or Chromium first)"
      fi
      log "Alternatively, check $LOG_DIR/chromedriver.log for the error."
      printf "\nSkip web tests and continue? [Y/n]: " >&2
      read -r skip_web_answer </dev/tty
      if [[ "$skip_web_answer" =~ ^[Nn]$ ]]; then
        log "Aborted."
        exit 1
      fi
      SKIP_WEB=true
    fi
  fi
fi

# ── Header ────────────────────────────────────────────────────────────────────
log ""
log "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
log "${YELLOW}  Flureadium Integration Test Runner${NC}"
log "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
log "Plugin:  $PLUGIN_DIR"
log "Logs:    $LOG_DIR"
[ -n "$ANDROID_DEVICE" ] && log "Android: $ANDROID_DEVICE"
[ -n "$IOS_DEVICE" ]     && log "iOS:     $IOS_DEVICE"
log ""

cd "$EXAMPLE_DIR"
OVERALL_EXIT=0

# ── Android ───────────────────────────────────────────────────────────────────
log "${CYAN}── Android ──────────────────────────────────────────────────────────${NC}"
if [ "$SKIP_ANDROID" = false ]; then
  if ! run_test \
      "Android — flutter test integration_test/all_tests.dart" \
      "$LOG_DIR/android.log" \
      flutter test integration_test/all_tests.dart \
        -d "$ANDROID_DEVICE"; then
    OVERALL_EXIT=1
  fi
else
  log "  Skipped (${ANDROID_SKIP_REASON:-explicitly skipped})"
fi

# ── iOS ───────────────────────────────────────────────────────────────────────
log ""
log "${CYAN}── iOS ──────────────────────────────────────────────────────────────${NC}"
if [ "$SKIP_IOS" = false ]; then
  if ! run_test \
      "iOS — flutter test integration_test/all_tests.dart (includes @native audiobook)" \
      "$LOG_DIR/ios.log" \
      flutter test integration_test/all_tests.dart \
        -d "$IOS_DEVICE"; then
    OVERALL_EXIT=1
  fi
else
  log "  Skipped (${IOS_SKIP_REASON:-explicitly skipped})"
fi

# ── Web ───────────────────────────────────────────────────────────────────────
log ""
log "${CYAN}── Web ──────────────────────────────────────────────────────────────${NC}"
if [ "$SKIP_WEB" = false ]; then
  if ! run_test \
      "Web — flutter drive --profile (launch smoke test only)" \
      "$LOG_DIR/web.log" \
      flutter drive \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/all_tests_web.dart \
        -d chrome \
        --profile; then
    OVERALL_EXIT=1
  fi
else
  log "  Skipped (explicitly skipped or ChromeDriver unavailable)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
log ""
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
if [ $OVERALL_EXIT -eq 0 ]; then
  log "${GREEN}All tests passed.${NC}"
else
  log "${RED}One or more tests failed.${NC}"
  log "Logs: $LOG_DIR/"
  if [ "$VERBOSE" = false ]; then
    log "Re-run with --verbose to see full flutter output inline."
  fi
fi
log "${CYAN}══════════════════════════════════════════════════════════════════${NC}"

exit $OVERALL_EXIT
