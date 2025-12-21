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
export KICAD8_SYMBOL_DIR="/Applications/KiCad/KiCad.app/Contents/SharedSupport/symbols"
export GEMINI_MODEL="gemini-3-pro-preview"

# Added by Antigravity
export PATH="/Users/andrewsager/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=512000
export SPICE_SCRIPTS=/opt/homebrew/share/ngspice/scripts

# Git worktree shortcut: wkt <name> creates ../wkt-<name> with branch wkt-<name> based on main
wkt() {
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
      --no-assets|--no-venv|--no-node|--dry-run|--force|-h|--help)
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

  if [[ -z "$name" ]]; then
    echo "usage: wkt <name>" >&2
    return 2
  fi

  local canonical
  canonical="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1

  local repo_wkt="$canonical/tools/wkt"
  if [[ -x "$repo_wkt" ]]; then
    "$repo_wkt" "$@"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
      return $rc
    fi
    if [[ "$has_custom_path" -eq 0 ]]; then
      local parent
      local dest
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
    return 0
  fi

  local dest="../wkt-$name"

  git worktree add "$dest" -b "wkt-$name" main

  if [[ -x "$HOME/.local/bin/setup_worktree.sh" ]]; then
    (cd "$dest" && WKT_CANONICAL_ROOT="$canonical" "$HOME/.local/bin/setup_worktree.sh")
  else
    echo "warning: ~/.local/bin/setup_worktree.sh not found or not executable" >&2
  fi

  cd "$dest"
}

# Remove a git worktree created by wkt
wkt-rm() {
  if [[ -z "${1:-}" ]]; then
    echo "usage: wkt-rm <name>" >&2
    echo "       wkt-rm .       (from top-level of a wkt)" >&2
    return 2
  fi

  local canonical
  canonical="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  local repo_wkt_rm="$canonical/tools/wkt-rm"
  if [[ -x "$repo_wkt_rm" ]]; then
    "$repo_wkt_rm" "$@"
    return $?
  fi

  local name="$1"
  local abs_worktree
  local branch

  # Handle "." - remove current worktree if at top-level
  if [[ "$name" == "." ]]; then
    local toplevel
    toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || {
      echo "error: not in a git repository" >&2
      return 1
    }

    # Check we're at the top-level, not a subdirectory
    # Use pwd -P to resolve symlinks (e.g., /tmp -> /private/tmp on macOS)
    if [[ "$(pwd -P)" != "$(cd "$toplevel" && pwd -P)" ]]; then
      echo "error: must be at worktree top-level, not a subdirectory" >&2
      echo "       current: $(pwd)" >&2
      echo "       toplevel: $toplevel" >&2
      return 1
    fi

    # Check directory name matches wkt-* pattern
    local dirname
    dirname="$(basename "$toplevel")"
    if [[ "$dirname" != wkt-* ]]; then
      echo "error: not a wkt worktree (directory doesn't match wkt-* pattern)" >&2
      return 1
    fi

    # Extract name from wkt-<name>
    name="${dirname#wkt-}"
    abs_worktree="$toplevel"
    branch="wkt-$name"

    # cd to parent before removing (so we don't get stuck)
    cd "$toplevel/.." || return 1
    echo "moved to $(pwd)"
  else
    local worktree="../wkt-$name"
    branch="wkt-$name"
    # Resolve to absolute path
    abs_worktree="$(cd "$(dirname "$worktree")" 2>/dev/null && pwd)/$(basename "$worktree")"
  fi

  # Check if worktree is clean (no diffs, no untracked files)
  local is_clean=false
  if git -C "$abs_worktree" diff --quiet 2>/dev/null && \
     git -C "$abs_worktree" diff --cached --quiet 2>/dev/null && \
     [[ -z "$(git -C "$abs_worktree" ls-files --others --exclude-standard 2>/dev/null)" ]]; then
    is_clean=true
  fi

  if [[ "$is_clean" == "false" ]]; then
    # Worktree has uncommitted changes or untracked files
    echo "warning: worktree has uncommitted changes or untracked files" >&2
    git -C "$abs_worktree" status --short >&2
    read "confirm?Remove anyway? [y/N] "
    [[ "$confirm" =~ ^[Yy]$ ]] || return 1
  elif ! git -C "$abs_worktree" branch --merged main 2>/dev/null | grep -qw "$branch"; then
    # Clean but has unmerged commits
    echo "warning: $branch has commits not merged to main" >&2
    read "confirm?Remove anyway? [y/N] "
    [[ "$confirm" =~ ^[Yy]$ ]] || return 1
  fi

  # Get the git common dir BEFORE removing (needed for branch ops after worktree is gone)
  local git_dir
  git_dir="$(git -C "$abs_worktree" rev-parse --git-common-dir 2>/dev/null)" || git_dir=""

  # Remove worktree (--force if dirty)
  # Use -C to ensure git commands work even after cd-ing out of worktree
  if git -C "$abs_worktree" worktree remove "$abs_worktree" 2>/dev/null || \
     git -C "$abs_worktree" worktree remove --force "$abs_worktree" 2>/dev/null; then
    echo "removed worktree: $abs_worktree"
  else
    echo "error: failed to remove worktree $abs_worktree" >&2
    return 1
  fi

  # Delete branch if it exists
  if [[ -n "$git_dir" ]]; then
    if git --git-dir="$git_dir" branch -d "$branch" 2>/dev/null; then
      echo "deleted branch: $branch"
    elif git --git-dir="$git_dir" branch -D "$branch" 2>/dev/null; then
      echo "force-deleted branch: $branch (was not fully merged)"
    fi
    git --git-dir="$git_dir" worktree prune
  fi
}
