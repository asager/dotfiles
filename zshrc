export PS1='%30<...<%~%<<%# '
alias pip='pip3'
alias python='python3'
alias py='python3'
alias cls="printf '\033c\e[3J'"
export PATH="/Applications/KiCad/KiCad.app/Contents/MacOS:$PATH"
alias py3=python3
alias g='gemini --yolo'
alias c='claude --dangerously-skip-permissions'
alias co='codex --yolo'
alias aeglos='cd ~/Documents/Aeglos'
export KICAD8_SYMBOL_DIR="/Applications/KiCad/KiCad.app/Contents/SharedSupport/symbols"

# Added by Antigravity
export PATH="/Users/andrewsager/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/Code/wkt/bin:$HOME/.local/bin:$HOME/bin:$PATH"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=512000
export SPICE_SCRIPTS=/opt/homebrew/share/ngspice/scripts

# Git worktree management - uses centralized ~/Code/wkt scripts
wkt() {
  # Parse name from args for cd-after-create
  local name=""
  local has_custom_path=0
  local i=1
  local arg
  while [[ $i -le $# ]]; do
    arg="${@[$i]}"
    case "$arg" in
      --canonical|--parent|--path)
        has_custom_path=1
        i=$((i + 1))
        ;;
      --canonical=*|--parent=*|--path=*)
        has_custom_path=1
        ;;
      --dry-run|-h|--help)
        # Don't cd for these
        command wkt "$@"
        return $?
        ;;
      -*)
        ;;
      *)
        if [[ -z "$name" ]]; then
          name="$arg"
        fi
        ;;
    esac
    i=$((i + 1))
  done

  command wkt "$@"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    return $rc
  fi

  # cd to new worktree if created with default path
  if [[ -n "$name" && "$has_custom_path" -eq 0 ]]; then
    local canonical
    canonical="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
    # Get canonical root (handles being in a worktree)
    local git_common
    git_common="$(git rev-parse --git-common-dir 2>/dev/null)"
    git_common="$(cd "$canonical" && cd "$git_common" && pwd -P)"
    canonical="$(dirname "$git_common")"

    local parent dest
    parent="$(dirname "$canonical")"
    if [[ "$name" == wkt-* ]]; then
      dest="$parent/$name"
    else
      dest="$parent/wkt-$name"
    fi
    if [[ -d "$dest" ]]; then
      cd "$dest" || return 1
    fi
  fi
}

# Remove a git worktree
wkt-rm() {
  command wkt-rm "$@"
}
source /Users/andrewsager/google-cloud-sdk/path.zsh.inc
source /Users/andrewsager/google-cloud-sdk/completion.zsh.inc

# Private credentials (API keys, etc)
[[ -f ~/.secrets ]] && source ~/.secrets

export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin
# opencode
export PATH=/Users/andrewsager/.opencode/bin:$PATH
