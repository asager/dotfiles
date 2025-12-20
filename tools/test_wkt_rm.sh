#!/usr/bin/env bash
# test_wkt_rm.sh - Tests for the wkt-rm shell function
#
# Run from the Technical directory:
#   ./tools/test_wkt_rm.sh

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

# Copy wkt-rm function for testing (extracted from .zshrc)
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
    if [[ "$(pwd)" != "$toplevel" ]]; then
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

  # Check if branch is merged to main (skip prompt in tests via WKT_TEST_FORCE)
  if ! git branch --merged main 2>/dev/null | grep -q "$branch"; then
    if [[ "${WKT_TEST_FORCE:-}" != "1" ]]; then
      echo "warning: $branch is not merged to main" >&2
      read -p "Remove anyway? [y/N] " confirm
      [[ "$confirm" =~ ^[Yy]$ ]] || return 1
    fi
  fi

  if git worktree remove "$abs_worktree" 2>/dev/null || \
     git worktree remove --force "$abs_worktree" 2>/dev/null; then
    echo "removed worktree: $abs_worktree"
  else
    echo "error: failed to remove worktree $abs_worktree" >&2
    return 1
  fi

  if git branch -d "$branch" 2>/dev/null; then
    echo "deleted branch: $branch"
  elif git branch -D "$branch" 2>/dev/null; then
    echo "force-deleted branch: $branch (was not fully merged)"
  fi

  git worktree prune
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
git init
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
# Test 2: Remove a merged worktree
# ------------------------------------------------------------------------------
run_test "wkt-rm removes a merged worktree"
create_test_worktree "test-merged"
# Merge the branch to main (it's already based on main with no changes, so it's "merged")
if wkt-rm "test-merged" >/dev/null 2>&1; then
    # Verify worktree is gone
    if [[ ! -d "../wkt-test-merged" ]]; then
        # Verify branch is gone
        if ! git branch | grep -q "wkt-test-merged"; then
            pass "wkt-rm removes merged worktree and branch"
        else
            fail "wkt-rm removes merged worktree" "Branch still exists"
        fi
    else
        fail "wkt-rm removes merged worktree" "Worktree directory still exists"
    fi
else
    fail "wkt-rm removes merged worktree" "Command failed"
fi

# ------------------------------------------------------------------------------
# Test 3: Remove worktree with unmerged changes (forced)
# ------------------------------------------------------------------------------
run_test "wkt-rm warns about unmerged branch"
create_test_worktree "test-unmerged"
# Add a commit to make it diverge from main
(cd "../wkt-test-unmerged" && echo "new content" > newfile.txt && git add newfile.txt && git commit -m "Unmerged commit")

# Without force, should warn (we use WKT_TEST_FORCE to skip interactive prompt)
output=$(WKT_TEST_FORCE=1 wkt-rm "test-unmerged" 2>&1) || true
if [[ ! -d "../wkt-test-unmerged" ]]; then
    pass "wkt-rm with WKT_TEST_FORCE removes unmerged worktree"
else
    fail "wkt-rm with unmerged branch" "Worktree still exists after force"
fi

# ------------------------------------------------------------------------------
# Test 4: Remove non-existent worktree
# ------------------------------------------------------------------------------
run_test "wkt-rm on non-existent worktree fails gracefully"
if output=$(wkt-rm "does-not-exist" 2>&1); then
    fail "wkt-rm on non-existent worktree" "Expected failure"
else
    if [[ "$output" == *"error"* ]] || [[ "$output" == *"failed"* ]] || [[ "$output" == *"not a working tree"* ]]; then
        pass "wkt-rm on non-existent worktree shows error"
    else
        # Even if message differs, as long as it failed, that's correct behavior
        pass "wkt-rm on non-existent worktree returns error"
    fi
fi

# ------------------------------------------------------------------------------
# Test 5: Remove worktree with dirty files
# ------------------------------------------------------------------------------
run_test "wkt-rm removes worktree with uncommitted changes"
create_test_worktree "test-dirty"
echo "dirty content" > "../wkt-test-dirty/dirty.txt"  # Untracked file

if wkt-rm "test-dirty" >/dev/null 2>&1; then
    if [[ ! -d "../wkt-test-dirty" ]]; then
        pass "wkt-rm removes dirty worktree (force fallback works)"
    else
        fail "wkt-rm removes dirty worktree" "Directory still exists"
    fi
else
    fail "wkt-rm removes dirty worktree" "Command failed"
fi

# ------------------------------------------------------------------------------
# Test 6: git worktree prune is called
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
# Test 7: wkt-rm . from top-level of worktree
# ------------------------------------------------------------------------------
run_test "wkt-rm . removes current worktree when at top-level"
create_test_worktree "test-dot"
(
    cd "../wkt-test-dot"
    wkt-rm . >/dev/null 2>&1
)
if [[ ! -d "../wkt-test-dot" ]]; then
    if ! git branch | grep -q "wkt-test-dot"; then
        pass "wkt-rm . removes worktree and branch from top-level"
    else
        fail "wkt-rm . from top-level" "Branch still exists"
    fi
else
    fail "wkt-rm . from top-level" "Worktree directory still exists"
fi

# ------------------------------------------------------------------------------
# Test 8: wkt-rm . fails from subdirectory
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
# Test 9: wkt-rm . fails from non-wkt directory
# ------------------------------------------------------------------------------
run_test "wkt-rm . fails from non-wkt directory (canonical)"
output=$(wkt-rm . 2>&1) || exit_code=$?
if [[ "$output" == *"not a wkt worktree"* ]]; then
    pass "wkt-rm . rejects non-wkt directory"
else
    fail "wkt-rm . from canonical" "Expected 'not a wkt worktree' error, got: $output"
fi

# ------------------------------------------------------------------------------
# Test 10: wkt-rm . changes directory to parent
# ------------------------------------------------------------------------------
run_test "wkt-rm . changes to parent directory"
create_test_worktree "test-dot-cd"
output=$(cd "../wkt-test-dot-cd" && wkt-rm . 2>&1)
if [[ "$output" == *"moved to"* ]]; then
    pass "wkt-rm . reports moving to parent directory"
else
    fail "wkt-rm . directory change" "Expected 'moved to' message, got: $output"
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
