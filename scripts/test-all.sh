#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_UNIT=true
RUN_CLI=true

for arg in "$@"; do
  case "$arg" in
    --unit)
      RUN_CLI=false
      ;;
    --cli)
      RUN_UNIT=false
      ;;
    --all)
      RUN_UNIT=true
      RUN_CLI=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: scripts/test-all.sh [--all|--unit|--cli]"
      exit 2
      ;;
  esac
done

BUILD_HOME="$ROOT_DIR"
MODULE_CACHE="$ROOT_DIR/.build/module-cache"
CLANG_CACHE="$ROOT_DIR/.build/clang-module-cache"
CLI_CONFIG_DIR="$ROOT_DIR/.build/test-cli-config"

mkdir -p "$MODULE_CACHE" "$CLANG_CACHE" "$CLI_CONFIG_DIR"

run_unit_tests() {
  echo "==> Running XCTest suite"
  HOME="$BUILD_HOME" \
    SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
    CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
    swift test --disable-sandbox
}

run_cli_smoke_tests() {
  echo "==> Building macsnap-cli"
  HOME="$BUILD_HOME" \
    SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
    CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
    swift build --disable-sandbox --product macsnap-cli

  local cli_bin="$ROOT_DIR/.build/debug/macsnap-cli"
  if [[ ! -x "$cli_bin" ]]; then
    echo "Expected CLI binary at $cli_bin"
    exit 1
  fi

  rm -rf "$CLI_CONFIG_DIR"
  mkdir -p "$CLI_CONFIG_DIR"

  echo "==> Running CLI smoke tests"

  local json_output
  json_output="$(MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" list-config --json)"
  [[ "$json_output" == *'"output"'* ]] || { echo "list-config --json missing output section"; exit 1; }
  [[ "$json_output" == *'"capture"'* ]] || { echo "list-config --json missing capture section"; exit 1; }

  MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config output.format jpg >/dev/null
  current_format="$(MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config output.format)"
  [[ "$current_format" == "jpg" ]] || { echo "Expected output.format=jpg, got $current_format"; exit 1; }

  MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config shortcuts.fullScreen "cmd+option+9" >/dev/null
  current_shortcut="$(MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config shortcuts.fullScreen)"
  [[ "$current_shortcut" == "cmd+option+9" ]] || { echo "Expected shortcuts.fullScreen=cmd+option+9, got $current_shortcut"; exit 1; }

  MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config capture.previewDuration 4.5 >/dev/null
  current_preview_duration="$(MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config capture.previewDuration)"
  [[ "$current_preview_duration" == "4.5" ]] || { echo "Expected capture.previewDuration=4.5, got $current_preview_duration"; exit 1; }

  if MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config output.jpgQuality 999 >/dev/null 2>&1; then
    echo "Expected invalid jpgQuality to fail"
    exit 1
  fi

  if MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" config capture.previewDuration not-a-number >/dev/null 2>&1; then
    echo "Expected invalid capture.previewDuration to fail"
    exit 1
  fi

  MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" reset-config --force >/dev/null

  if MACSNAP_CONFIG_DIR="$CLI_CONFIG_DIR" "$cli_bin" capture invalid >/dev/null 2>&1; then
    echo "Expected invalid capture mode to fail"
    exit 1
  fi

  echo "CLI smoke tests passed"
}

if [[ "$RUN_UNIT" == true ]]; then
  run_unit_tests
fi

if [[ "$RUN_CLI" == true ]]; then
  run_cli_smoke_tests
fi

echo "All requested tests passed"
