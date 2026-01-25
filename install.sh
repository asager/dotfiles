#!/bin/bash
# Dotfiles install script
# Creates symlinks from home directory to dotfiles repo

set -e

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

echo "Installing dotfiles from $DOTFILES_DIR"
echo ""

# Obsolete files we no longer manage
remove_obsolete_link "config/ghostty/config" ".config/ghostty/config"

for entry in "${FILES[@]}"; do
    src="${entry%%|*}"
    dest="${entry##*|}"
    backup_and_link "$src" "$dest"
done

echo ""
echo "Done! Backups saved to: $BACKUP_DIR"
echo "Restart your shell or run: source ~/.zshrc"
