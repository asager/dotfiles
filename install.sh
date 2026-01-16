#!/bin/bash
# Dotfiles install script
# Creates symlinks from home directory to dotfiles repo

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Files to symlink: "source|target" (source relative to DOTFILES_DIR, target relative to HOME)
FILES=(
    "zshrc|.zshrc"
    "gitconfig|.gitconfig"
    "config/ghostty/config|.config/ghostty/config"
    "config/rclone/rclone.conf|.config/rclone/rclone.conf"
    "tools/setup_worktree.sh|.local/bin/setup_worktree.sh"
    "tools/test_wkt_rm.sh|.local/bin/test_wkt_rm.sh"
    "config/claude/statusline.sh|.claude/statusline.sh"
    "config/git/ignore|.config/git/ignore"
)

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

for entry in "${FILES[@]}"; do
    src="${entry%%|*}"
    dest="${entry##*|}"
    backup_and_link "$src" "$dest"
done

echo ""
echo "Done! Backups saved to: $BACKUP_DIR"
echo "Restart your shell or run: source ~/.zshrc"
