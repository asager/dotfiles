#!/bin/bash
# Dotfiles install script
# Creates symlinks from home directory to dotfiles repo
# Optionally bootstraps dev tooling via Homebrew.

set -e

usage() {
    cat <<'EOF'
usage: ./install.sh [--skip-brew]

Creates symlinks into your home directory.

By default this also runs:
  brew bundle --file ~/dotfiles/Brewfile

Options:
  --skip-brew   Skip Homebrew bootstrap + Brewfile install
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

SKIP_BREW=0
if [[ "${1:-}" == "--skip-brew" ]]; then
    SKIP_BREW=1
    shift
fi

# If invoked via sudo, re-run as the original user.
# Homebrew refuses to run as root, and we want dotfiles to land in the user's home.
if [[ "${DOTFILES_FROM_SUDO:-}" != "1" && "${EUID:-$(id -u)}" -eq 0 ]]; then
    if [[ -z "${SUDO_USER:-}" || "${SUDO_USER}" == "root" ]]; then
        echo "error: do not run as root; run as your normal user" >&2
        exit 1
    fi
    exec sudo -u "${SUDO_USER}" -H DOTFILES_FROM_SUDO=1 bash "$0" "$@"
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Files to symlink: "source|target" (source relative to DOTFILES_DIR, target relative to HOME)
FILES=(
    "zprofile|.zprofile"
    "zshrc|.zshrc"
    "gitconfig|.gitconfig"
    "config/rclone/rclone.conf|.config/rclone/rclone.conf"
    "tools/setup_worktree.sh|.local/bin/setup_worktree.sh"
    "tools/test_wkt_rm.sh|.local/bin/test_wkt_rm.sh"
    "tools/launchagent_reload.sh|.local/bin/launchagent-reload"
    "tools/deploy_menubarhelper.sh|.local/bin/deploy-menubarhelper"
    "tools/setup_opencode.sh|.local/bin/setup-opencode"
    "tools/bootstrap_repos.sh|.local/bin/bootstrap-repos"
    "tools/azure_ocr.py|bin/azure_ocr"
    "config/claude/statusline.sh|.claude/statusline.sh"
    "config/claude/CLAUDE.md|.claude/CLAUDE.md"
    "config/codex/AGENTS.md|.codex/AGENTS.md"
    "config/codex/config.toml|.codex/config.toml"
    "config/gemini/GEMINI.md|.gemini/GEMINI.md"
    "config/gemini/settings.json|.gemini/settings.json"
    "config/git/ignore|.config/git/ignore"
    "config/gh/config.yml|.config/gh/config.yml"
    "config/wkt/config.yaml|.config/wkt/config.yaml"
    "config/opencode/opencode.json|.config/opencode/opencode.json"
    "config/opencode/quotes.txt|.config/opencode/quotes.txt"
    "config/opencode/package.json|.config/opencode/package.json"
    "config/opencode/bun.lock|.config/opencode/bun.lock"
    "config/launchagents/com.andrewsager.menubarhelper.plist|Library/LaunchAgents/com.andrewsager.menubarhelper.plist"
    "config/launchagents/com.andrewsager.codex-tui-notify.plist|Library/LaunchAgents/com.andrewsager.codex-tui-notify.plist"
    "opencode.json|Code/opencode.json"
)

remove_obsolete_link() {
    local expected_src="$DOTFILES_DIR/$1"
    local dest="$HOME/$2"

    # If the destination is a symlink pointing to our dotfiles copy, remove it.
    if [[ -L "$dest" && "$(readlink "$dest")" == "$expected_src" ]]; then
        echo "Removing obsolete link: $2"
        mkdir -p "$(dirname "$BACKUP_DIR/$2")"
        mv "$dest" "$BACKUP_DIR/$2"
    fi
}

backup_and_link() {
    local src="$DOTFILES_DIR/$1"
    local dest="$HOME/$2"
    local dest_dir="$(dirname "$dest")"

    # Create destination directory if needed
    if [[ ! -d "$dest_dir" ]]; then
        echo "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi

    # Backup existing file if it exists and is not already a symlink to our file
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
            echo "Already linked: $2"
            return
        fi
        echo "Backing up: $dest -> $BACKUP_DIR/$2"
        mkdir -p "$(dirname "$BACKUP_DIR/$2")"
        mv "$dest" "$BACKUP_DIR/$2"
    fi

    # Create symlink
    echo "Linking: $dest -> $src"
    ln -s "$src" "$dest"
}

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
        return 0
    fi

    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
}

run_brew_bundle() {
    ensure_homebrew

    # Ensure brew is on PATH in this non-login shell
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
        echo "warning: Brewfile not found at $DOTFILES_DIR/Brewfile" >&2
        return 0
    fi

    echo ""
    echo "Installing brew dependencies from Brewfile..."
    brew update >/dev/null 2>&1 || true
    brew tap homebrew/core >/dev/null 2>&1 || true
    brew tap homebrew/cask >/dev/null 2>&1 || true
    brew tap homebrew/bundle >/dev/null 2>&1 || true
    brew tap oven-sh/bun >/dev/null 2>&1 || true
    brew bundle --file "$DOTFILES_DIR/Brewfile"
}

echo "Installing dotfiles from $DOTFILES_DIR"
echo ""

# Obsolete files we no longer manage
remove_obsolete_link "config/ghostty/config" ".config/ghostty/config"

for entry in "${FILES[@]}"; do
    src="${entry%%|*}"
    dest="${entry##*|}"
    backup_and_link "$src" "$dest"
done

if [[ "$SKIP_BREW" -eq 0 ]]; then
    run_brew_bundle

    # Install OpenCode plugin deps (requires bun).
    if [[ -x "$HOME/.local/bin/setup-opencode" ]]; then
        "$HOME/.local/bin/setup-opencode" || true
    fi
else
    echo ""
    echo "Skipping Homebrew bootstrap (--skip-brew)"
fi

echo ""
echo "Done! Backups saved to: $BACKUP_DIR"
echo "Restart your shell or run: source ~/.zshrc"
