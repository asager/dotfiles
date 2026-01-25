#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: launchagent-reload <label|plist>" >&2
  echo "  examples:" >&2
  echo "    launchagent-reload com.andrewsager.menubarhelper" >&2
  echo "    launchagent-reload ~/Library/LaunchAgents/com.andrewsager.menubarhelper.plist" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

arg="$1"
uid="$(id -u)"
domain="gui/${uid}"

plist=""
label=""

if [[ "$arg" == *".plist"* ]]; then
  plist="$arg"
  [[ "$plist" != /* ]] && plist="$HOME/Library/LaunchAgents/$plist"
  if [[ ! -f "$plist" ]]; then
    echo "error: plist not found: $plist" >&2
    exit 1
  fi

  label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$plist" 2>/dev/null || true)"
  [[ -z "$label" ]] && label="$(basename "$plist" .plist)"
else
  label="$arg"
  if [[ -f "$HOME/Library/LaunchAgents/$label.plist" ]]; then
    plist="$HOME/Library/LaunchAgents/$label.plist"
  fi
fi

if [[ -n "$plist" ]]; then
  launchctl bootout "$domain" "$plist" 2>/dev/null || true
  launchctl bootstrap "$domain" "$plist"
  launchctl enable "$domain/$label" 2>/dev/null || true
  launchctl kickstart -k "$domain/$label" 2>/dev/null || true
  echo "reloaded: $label"
else
  launchctl kickstart -k "$domain/$label" 2>/dev/null || {
    echo "error: couldn't kickstart $domain/$label (plist not found)" >&2
    exit 1
  }
  echo "kickstarted: $label"
fi
