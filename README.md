# dotfiles

Personal dotfiles for macOS.

## Contents

- `zshrc` - Zsh configuration (aliases, PATH, wkt helpers, OpenCode helpers)
- `zprofile` - Login shell setup (Homebrew + Python PATH)
- `gitconfig` - Git user settings and aliases
- `config/git/ignore` - Global gitignore (intended for `core.excludesfile`)
- `config/gh/config.yml` - GitHub CLI config (non-secret)
- `config/rclone/rclone.conf` - rclone remote aliases

- `config/claude/*` - Claude Code instructions + statusline
- `config/codex/*` - Codex instructions + config
- `config/gemini/*` - Gemini instructions + settings

- `config/opencode/*` - OpenCode config (status bar + plugin deps)
- `opencode.json` - OpenCode workspace permissions (symlinked to `~/Code/opencode.json`)

- `config/wkt/config.yaml` - wkt global config
- `config/launchagents/*` - launchd LaunchAgents for local automation

- `tools/*` - utility scripts (installed to `~/.local/bin` and `~/bin`)
- `Brewfile` - optional `brew bundle` snapshot of core tooling

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
3. Install CLI+GUI tooling via `brew bundle` (unless `--skip-brew`)
4. Load common LaunchAgents (unless `--skip-launchagents`)
5. Import app defaults (unless `--skip-app-defaults`)

## Post-install

- Install core brew deps (automatic by default): `brew bundle --file ~/dotfiles/Brewfile`
- Clone your core repos (optional): `bootstrap-repos`
- Install OpenCode plugin deps: `setup-opencode`
- (Re)deploy Everything MenuBarHelper: `deploy-menubarhelper`

## Adding New Dotfiles

1. Copy the file into this repo (without the leading dot)
2. Add an entry to the `FILES` array in `install.sh`
3. Run `./install.sh` to create the symlink
