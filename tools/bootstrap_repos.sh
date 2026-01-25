#!/usr/bin/env bash
set -euo pipefail

ensure_repo() {
  local url="$1"
  local dest="$2"
  local parent
  parent="$(dirname "$dest")"

  if [[ -d "$dest/.git" ]]; then
    echo "skip: $dest"
    return 0
  fi

  mkdir -p "$parent"
  echo "clone: $url -> $dest"
  git clone "$url" "$dest"
}

if ! command -v git >/dev/null 2>&1; then
  echo "error: git not found" >&2
  exit 1
fi

ensure_repo "https://github.com/asager/wkt.git" "$HOME/Code/wkt"
ensure_repo "https://github.com/asager/everything-app.git" "$HOME/Code/everything"
ensure_repo "https://github.com/asager/codex-tui-notify.git" "$HOME/Code/codex-tui-notify"
ensure_repo "https://github.com/anomalyco/opencode" "$HOME/Code/external/opencode"

echo "done"
