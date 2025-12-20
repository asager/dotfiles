#!/usr/bin/env bash
# tools/setup_worktree.sh
#
# Entry point for setting up a new git worktree.
# Called by the `wkt` shell function with WKT_CANONICAL_ROOT set.
#
# This script orchestrates:
#   1. Cloning large assets (via clone_assets.sh)
#   2. Cloning the Python venv (CoW copy for isolation)
#   3. Cloning node_modules directories (CoW copy for isolation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_ROOT="${WKT_CANONICAL_ROOT:-}"

if [[ -z "$CANONICAL_ROOT" ]]; then
    echo "error: WKT_CANONICAL_ROOT must be set" >&2
    exit 1
fi

echo "Setting up worktree: $WORKTREE_ROOT"
echo "Canonical root: $CANONICAL_ROOT"

# 1. Clone large assets
if [[ -x "$SCRIPT_DIR/clone_assets.sh" ]]; then
    echo ""
    echo "==> Cloning assets..."
    "$SCRIPT_DIR/clone_assets.sh"
else
    echo "warning: clone_assets.sh not found or not executable" >&2
fi

# 2. Clone .venv (CoW copy for worktree isolation)
clone_venv() {
    local src="$CANONICAL_ROOT/.venv"
    local dst="$WORKTREE_ROOT/.venv"

    if [[ ! -d "$src" ]]; then
        echo "warning: canonical .venv not found at $src" >&2
        echo "         You may need to create it: uv sync" >&2
        return 0
    fi

    if [[ -e "$dst" ]]; then
        echo "skip: .venv already exists"
        return 0
    fi

    echo ""
    echo "==> Cloning .venv (copy-on-write)..."

    # Try APFS CoW clone first, fall back to regular copy
    if cp -cR "$src" "$dst" 2>/dev/null; then
        echo "cloned .venv (APFS CoW)"
    elif ditto --clone "$src" "$dst" 2>/dev/null; then
        echo "cloned .venv (ditto CoW)"
    else
        cp -R "$src" "$dst"
        echo "copied .venv (no CoW available)"
    fi
}

clone_venv

# 3. Clone node_modules directories (CoW copy for isolation)
clone_node_modules() {
    # Find all package.json files in canonical (excluding node_modules themselves)
    while IFS= read -r -d '' pkg_json; do
        local rel_dir="${pkg_json#$CANONICAL_ROOT/}"
        rel_dir="$(dirname "$rel_dir")"

        local src="$CANONICAL_ROOT/$rel_dir/node_modules"
        local dst="$WORKTREE_ROOT/$rel_dir/node_modules"

        if [[ ! -d "$src" ]]; then
            continue
        fi

        if [[ -e "$dst" ]]; then
            echo "skip: $rel_dir/node_modules already exists"
            continue
        fi

        echo "==> Cloning $rel_dir/node_modules (copy-on-write)..."

        mkdir -p "$(dirname "$dst")"
        if cp -cR "$src" "$dst" 2>/dev/null; then
            echo "    cloned (APFS CoW)"
        elif ditto --clone "$src" "$dst" 2>/dev/null; then
            echo "    cloned (ditto CoW)"
        else
            cp -R "$src" "$dst"
            echo "    copied (no CoW available)"
        fi
    done < <(find "$CANONICAL_ROOT" -name "package.json" -not -path "*/node_modules/*" -print0 2>/dev/null)
}

clone_node_modules

echo ""
echo "Worktree setup complete."
