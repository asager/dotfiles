#!/usr/bin/env bash
# test_wkt_rm.sh - Tests for the wkt-rm shell function
#
# Run from anywhere:
#   ~/dotfiles/tools/test_wkt_rm.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test harness
pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ $1${NC}"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}✗ $1${NC}"
    echo -e "${RED}  $2${NC}"
}

run_test() {
    ((TESTS_RUN++))
    echo -e "${YELLOW}Running: $1${NC}"
}

# Create isolated test environment
ORIG_DIR="$(pwd)"
TEST_DIR="$(mktemp -d)"
trap 'cd "$ORIG_DIR"; rm -rf "$TEST_DIR"' EXIT

# Source the wkt-rm function from zshrc (extract it)
# We define it inline here for bash compatibility in tests
# NOTE: This should be kept in sync with ~/dotfiles/zshrc

wkt-rm() {
  if [[ -z "${1:-}" ]]; then
    echo "usage: wkt-rm <name>" >&2
    echo "       wkt-rm .       (from top-level of a wkt)" >&2
    return 2
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
    if [[ "${WKT_TEST_FORCE:-}" != "1" ]]; then
      read -r -p "Remove anyway? [y/N] " confirm
      [[ "$confirm" =~ ^[Yy]$ ]] || return 1
    fi
  elif ! git -C "$abs_worktree" branch --merged main 2>/dev/null | grep -qw "$branch"; then
    # Clean but has unmerged commits
    echo "warning: $branch has commits not merged to main" >&2
    if [[ "${WKT_TEST_FORCE:-}" != "1" ]]; then
      read -r -p "Remove anyway? [y/N] " confirm
      [[ "$confirm" =~ ^[Yy]$ ]] || return 1
    fi
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

# Helper to create a test worktree (mimics wkt)
create_test_worktree() {
  local name="$1"
  git worktree add "../wkt-$name" -b "wkt-$name" main
}

echo "=== Setting up test environment ==="
cd "$TEST_DIR"

# Create a "canonical" repo
mkdir canonical
cd canonical
git init -b main
git config user.email "test@example.com"
git config user.name "Test User"
echo "initial" > file.txt
git add file.txt
git commit -m "Initial commit"

echo ""
echo "=== Running tests ==="

# ------------------------------------------------------------------------------
# Test 1: No argument provided
# ------------------------------------------------------------------------------
run_test "wkt-rm with no argument returns error"
if output=$(wkt-rm 2>&1); then
    fail "wkt-rm with no argument" "Expected non-zero exit code"
else
    if [[ "$output" == *"usage: wkt-rm"* ]]; then
        pass "wkt-rm with no argument shows usage"
    else
        fail "wkt-rm with no argument" "Expected usage message, got: $output"
    fi
fi

# ------------------------------------------------------------------------------
# Test 2: CLEAN worktree (wkt then immediately wkt-rm) - should delete silently
# ------------------------------------------------------------------------------
run_test "wkt-rm on clean worktree (no changes) deletes without prompt"
create_test_worktree "test-clean"
# Verify the branch shows as merged (no new commits)
if git branch --merged main | grep -qw "wkt-test-clean"; then
    echo "  (branch correctly detected as merged to main)"
else
    echo "  DEBUG: git branch --merged main output:"
    git branch --merged main
fi
# Should not prompt because worktree is clean and branch is at main
output=$(wkt-rm "test-clean" 2>&1)
if [[ ! -d "../wkt-test-clean" ]]; then
    if [[ "$output" != *"warning"* ]] && [[ "$output" != *"Remove anyway"* ]]; then
        pass "wkt-rm on clean worktree deletes silently (no prompt)"
    else
        fail "wkt-rm on clean worktree" "Should not show warnings, got: $output"
    fi
else
    fail "wkt-rm on clean worktree" "Worktree still exists"
fi

# ------------------------------------------------------------------------------
# Test 3: Remove worktree with unmerged commits (should warn)
# ------------------------------------------------------------------------------
run_test "wkt-rm warns about unmerged commits"
create_test_worktree "test-unmerged"
# Add a commit to make it diverge from main
(cd "../wkt-test-unmerged" && echo "new content" > newfile.txt && git add newfile.txt && git commit -m "Unmerged commit")

output=$(WKT_TEST_FORCE=1 wkt-rm "test-unmerged" 2>&1) || true
if [[ "$output" == *"has commits not merged to main"* ]]; then
    pass "wkt-rm warns about unmerged commits"
else
    fail "wkt-rm with unmerged commits" "Expected warning about unmerged commits, got: $output"
fi

# ------------------------------------------------------------------------------
# Test 4: Remove worktree with dirty files (should warn)
# ------------------------------------------------------------------------------
run_test "wkt-rm warns about uncommitted changes"
create_test_worktree "test-dirty"
echo "dirty content" > "../wkt-test-dirty/dirty.txt"  # Untracked file

output=$(WKT_TEST_FORCE=1 wkt-rm "test-dirty" 2>&1)
if [[ "$output" == *"uncommitted changes or untracked"* ]]; then
    if [[ ! -d "../wkt-test-dirty" ]]; then
        pass "wkt-rm warns about dirty worktree and removes with force"
    else
        fail "wkt-rm with dirty worktree" "Directory still exists after force"
    fi
else
    fail "wkt-rm with dirty worktree" "Expected warning about uncommitted changes, got: $output"
fi

# ------------------------------------------------------------------------------
# Test 5: wkt-rm . from top-level of clean worktree
# ------------------------------------------------------------------------------
run_test "wkt-rm . on clean worktree deletes without prompt"
create_test_worktree "test-dot-clean"
output=$(cd "../wkt-test-dot-clean" && wkt-rm . 2>&1)
if [[ ! -d "../wkt-test-dot-clean" ]]; then
    if [[ "$output" == *"moved to"* ]] && [[ "$output" != *"warning"* ]]; then
        pass "wkt-rm . on clean worktree deletes silently"
    else
        fail "wkt-rm . on clean worktree" "Should not show warnings, got: $output"
    fi
else
    fail "wkt-rm . on clean worktree" "Worktree still exists"
fi

# ------------------------------------------------------------------------------
# Test 6: wkt-rm . fails from subdirectory
# ------------------------------------------------------------------------------
run_test "wkt-rm . fails from subdirectory of worktree"
create_test_worktree "test-dot-subdir"
mkdir -p "../wkt-test-dot-subdir/some/subdir"
output=$(cd "../wkt-test-dot-subdir/some/subdir" && wkt-rm . 2>&1) || exit_code=$?
if [[ "$output" == *"must be at worktree top-level"* ]]; then
    pass "wkt-rm . rejects subdirectory with correct error"
    # Cleanup
    wkt-rm "test-dot-subdir" >/dev/null 2>&1 || true
else
    fail "wkt-rm . from subdirectory" "Expected 'must be at worktree top-level' error, got: $output"
fi

# ------------------------------------------------------------------------------
# Test 7: wkt-rm . fails from non-wkt directory
# ------------------------------------------------------------------------------
run_test "wkt-rm . fails from non-wkt directory (canonical)"
output=$(wkt-rm . 2>&1) || exit_code=$?
if [[ "$output" == *"not a wkt worktree"* ]]; then
    pass "wkt-rm . rejects non-wkt directory"
else
    fail "wkt-rm . from canonical" "Expected 'not a wkt worktree' error, got: $output"
fi

# ------------------------------------------------------------------------------
# Test 8: Remove non-existent worktree
# ------------------------------------------------------------------------------
run_test "wkt-rm on non-existent worktree fails gracefully"
if output=$(wkt-rm "does-not-exist" 2>&1); then
    fail "wkt-rm on non-existent worktree" "Expected failure"
else
    pass "wkt-rm on non-existent worktree returns error"
fi

# ------------------------------------------------------------------------------
# Test 9: git worktree prune is called
# ------------------------------------------------------------------------------
run_test "wkt-rm prunes stale worktree references"
create_test_worktree "test-prune"
# Manually delete the directory (simulating stale reference)
rm -rf "../wkt-test-prune"
# Create another worktree to have something to remove
create_test_worktree "test-prune2"

# Remove the valid one - this should also prune the stale reference
wkt-rm "test-prune2" >/dev/null 2>&1 || true

# Check that stale reference was pruned
if git worktree list | grep -q "wkt-test-prune"; then
    fail "wkt-rm prunes stale references" "Stale worktree still in list"
else
    pass "wkt-rm prunes stale worktree references"
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "=== Test Summary ==="
echo -e "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
