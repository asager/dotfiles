#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$HOME/Code/everything"
SWIFT_DIR="$REPO_ROOT/swift/MenuBarHelper"
APP_DIR="$HOME/Applications/MenuBarHelper.app"
BIN="$SWIFT_DIR/.build/arm64-apple-macosx/release/MenuBarHelper"
PLIST="$SWIFT_DIR/Sources/Resources/Info.plist"
ICON="$REPO_ROOT/icon.icns"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.andrewsager.menubarhelper.plist"

if [[ ! -d "$SWIFT_DIR" ]]; then
  echo "error: not found: $SWIFT_DIR" >&2
  echo "hint: clone https://github.com/asager/everything-app.git to $REPO_ROOT" >&2
  exit 1
fi

echo "==> Building MenuBarHelper (release)"
rm -rf "$SWIFT_DIR/.build"
(cd "$SWIFT_DIR" && swift build -c release)

if [[ ! -f "$BIN" ]]; then
  echo "error: build output not found: $BIN" >&2
  exit 1
fi

echo "==> Creating app bundle: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/MenuBarHelper"
cp "$PLIST" "$APP_DIR/Contents/Info.plist"
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$APP_DIR/Contents/Resources/icon.icns"
fi
chmod +x "$APP_DIR/Contents/MacOS/MenuBarHelper"

echo "==> Restarting app"
killall MenuBarHelper 2>/dev/null || true
open "$APP_DIR"

if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
  echo "==> Reloading LaunchAgent"
  if command -v launchagent-reload >/dev/null 2>&1; then
    launchagent-reload "$LAUNCH_AGENT_PLIST" || true
  else
    launchctl kickstart -k "gui/$(id -u)/com.andrewsager.menubarhelper" 2>/dev/null || true
  fi
fi

echo "done"
