export PS1='%30<...<%~%<<%# '
alias pip='pip3'
alias python='python3'
alias py='python3'
alias cls="printf '\033c\e[3J'"
export PATH="/Applications/KiCad/KiCad.app/Contents/MacOS:$PATH"
alias py3=python3
alias g='gemini --yolo'
alias c='claude --dangerously-skip-permissions'
alias co="codex --yolo --add-dir $HOME/Documents/Aeglos --add-dir $HOME/Code"
alias aeglos='cd ~/Documents/Aeglos'
export KICAD8_SYMBOL_DIR="/Applications/KiCad/KiCad.app/Contents/SharedSupport/symbols"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/Code/wkt/bin:$HOME/.local/bin:$HOME/bin:$PATH"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=512000
export SPICE_SCRIPTS=/opt/homebrew/share/ngspice/scripts

# Git worktree management (wkt)
# Prefer sourcing wkt.sh (works in zsh + bash) instead of sourcing bin/wkt.
if [[ -f "$HOME/Code/wkt/wkt.sh" ]]; then
  source "$HOME/Code/wkt/wkt.sh"
fi
[[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]] && source "$HOME/google-cloud-sdk/path.zsh.inc"
[[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]] && source "$HOME/google-cloud-sdk/completion.zsh.inc"

# Private credentials (API keys, etc)
[[ -f ~/.secrets ]] && source ~/.secrets

export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin
# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# `oc` runs opencode without debug; `ocd` runs opencode with debug.
# Keeps the local-dev auto-install behavior (install-local) when the opencode repo is present.
_oc_repo_root="$HOME/Code/external/opencode"
_oc_install_log="$HOME/.opencode/logs/oc-statusbar.log"
_oc_version_marker="$HOME/.opencode/.last-opencode-version"

_oc_get_version() {
  OPENCODE_DISABLE_AUTOUPDATE=1 opencode --version 2>/dev/null || true
}

_oc_install_local_if_needed() {
  mkdir -p "$HOME/.opencode/logs"

  local before_version="$(_oc_get_version)"

  if [[ -n "${_oc_repo_root}" && -d "${_oc_repo_root}/packages/opencode" ]]; then
    if [[ -z "${before_version}" || "${before_version}" != *dev* ]]; then
      command bun run --cwd "${_oc_repo_root}/packages/opencode" install-local 1>>"${_oc_install_log}" 2>&1 || true
      before_version="$(_oc_get_version)"
    fi
  fi

  echo "${before_version}"
}

_oc_run() {
  local debug_value="$1"
  shift

  local before_version="$(_oc_install_local_if_needed)"

  OPENCODE_DISABLE_AUTOUPDATE=1 OPENCODE_STATUSBAR_DEBUG="${debug_value}" opencode "$@" 2> >(tee -a "${_oc_install_log}" >&2)

  local after_version="$(_oc_get_version)"
  if [[ -n "${after_version}" && "${after_version}" != "${before_version}" ]]; then
    if [[ -n "${_oc_repo_root}" && -d "${_oc_repo_root}/packages/opencode" ]]; then
      command bun run --cwd "${_oc_repo_root}/packages/opencode" install-local 1>>"${_oc_install_log}" 2>&1 || true
      _oc_get_version > "${_oc_version_marker}" 2>/dev/null || true
    fi
  fi
}

oc()  { _oc_run 0 "$@"; }
ocd() { _oc_run 1 "$@"; }

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
