# dotfiles

Personal dotfiles for macOS.

## Contents

- `zshrc` - Zsh configuration (aliases, functions, PATH)
- `gitconfig` - Git user settings and aliases
- `config/ghostty/config` - Ghostty terminal configuration
- `config/rclone/rclone.conf` - rclone remote aliases

## Installation

Clone and run the install script:

```bash
git clone https://github.com/asager/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script will:
1. Back up any existing dotfiles to `~/.dotfiles_backup/<timestamp>/`
2. Create symlinks from your home directory to this repo

## Adding New Dotfiles

1. Copy the file into this repo (without the leading dot)
2. Add an entry to the `FILES` array in `install.sh`
3. Run `./install.sh` to create the symlink
