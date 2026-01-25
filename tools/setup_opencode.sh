#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "error: $CONFIG_DIR does not exist" >&2
  echo "hint: run ~/dotfiles/install.sh first" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_DIR/package.json" ]]; then
  echo "error: $CONFIG_DIR/package.json not found" >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "error: bun not found" >&2
  echo "hint: install bun (or run: brew install bun)" >&2
  exit 1
fi

echo "==> Installing OpenCode plugin deps"
bun install --cwd "$CONFIG_DIR"

echo "ok: deps installed in $CONFIG_DIR"

if command -v opencode >/dev/null 2>&1; then
  OPENCODE_DISABLE_AUTOUPDATE=1 opencode --version || true
else
  echo "note: opencode binary not found on PATH" >&2
fi
