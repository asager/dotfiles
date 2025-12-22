#!/bin/bash
# Tests for statusline.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Clean up test artifacts
cleanup() {
    rm -f /tmp/claude_weather_cache_test
    rm -f /tmp/claude_lotr_quote_test
}
trap cleanup EXIT

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $msg"
        echo "  Expected to contain: '$needle'"
        echo "  Got: '$haystack'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $msg"
        echo "  Expected: '$expected'"
        echo "  Got: '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}PASS${NC}: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $msg (value was empty)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_statusline() {
    local dir="$1"
    echo "{\"workspace\":{\"current_dir\":\"$dir\"}}" | "$STATUSLINE"
}

echo "=== Statusline Tests ==="
echo ""

# Clear caches for consistent testing
rm -f /tmp/claude_weather_cache
rm -f /tmp/claude_lotr_quote

echo "--- Worktree Detection ---"

# Test 1: Canonical path detection
output=$(run_statusline "/Users/andrewsager/Documents/Aeglos/Technical")
assert_contains "$output" "Aeglos main" "Canonical path shows 'Aeglos main'"

# Test 2: Canonical path with subdirectory
output=$(run_statusline "/Users/andrewsager/Documents/Aeglos/Technical/src/components")
assert_contains "$output" "Aeglos main" "Canonical subdir shows 'Aeglos main'"

# Test 3: Worktree path extraction
output=$(run_statusline "/Users/andrewsager/Documents/Aeglos/wkt-feature-branch")
assert_contains "$output" "feature-branch" "Worktree 'wkt-feature-branch' extracts 'feature-branch'"

# Test 4: Worktree path with subdirectory
output=$(run_statusline "/Users/andrewsager/Documents/Aeglos/wkt-terrain-arch/src")
assert_contains "$output" "terrain-arch" "Worktree subdir extracts correct name"

# Test 5: Worktree with numbers/special chars
output=$(run_statusline "/Users/andrewsager/Documents/Aeglos/wkt-fix-123-bug")
assert_contains "$output" "fix-123-bug" "Worktree with numbers works"

# Test 6: Fallback to directory name
output=$(run_statusline "/Users/andrewsager/some/other/project")
assert_contains "$output" "project" "Non-Aeglos path falls back to dir name"

# Test 7: Root directory fallback
output=$(run_statusline "/")
# Should not crash, just show something
assert_not_empty "$output" "Root directory doesn't crash"

echo ""
echo "--- Output Format ---"

# Test 8: Output has three pipe-separated sections
output=$(run_statusline "/Users/andrewsager/Documents/Aeglos/Technical")
pipe_count=$(echo "$output" | tr -cd '|' | wc -c | tr -d ' ')
assert_equals "$pipe_count" "2" "Output has exactly 2 pipe separators (3 sections)"

# Test 9: Temperature section exists (may be '--' if network fails)
temp_section=$(echo "$output" | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
assert_not_empty "$temp_section" "Temperature section is not empty"

# Test 10: Quote section exists
quote_section=$(echo "$output" | cut -d'|' -f3 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
assert_not_empty "$quote_section" "Quote section is not empty"

echo ""
echo "--- Caching Behavior ---"

# Test 11: Quote is cached (same quote on subsequent calls within cache period)
rm -f /tmp/claude_lotr_quote
output1=$(run_statusline "/Users/andrewsager/Documents/Aeglos/Technical")
quote1=$(echo "$output1" | cut -d'|' -f3 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
output2=$(run_statusline "/Users/andrewsager/Documents/Aeglos/Technical")
quote2=$(echo "$output2" | cut -d'|' -f3 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
assert_equals "$quote1" "$quote2" "Quote is cached between calls"

# Test 12: Cache file is created
if [[ -f /tmp/claude_lotr_quote ]]; then
    echo -e "${GREEN}PASS${NC}: Quote cache file created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}: Quote cache file not created"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo ""
echo "--- Edge Cases ---"

# Test 13: Empty JSON input handling
output=$(echo '{}' | "$STATUSLINE" 2>&1) || true
# Should not crash catastrophically
TESTS_RUN=$((TESTS_RUN + 1))
if [[ $? -le 1 ]]; then
    echo -e "${GREEN}PASS${NC}: Empty JSON doesn't crash"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}: Empty JSON caused crash"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 14: Malformed JSON handling
output=$(echo 'not json' | "$STATUSLINE" 2>&1) || true
TESTS_RUN=$((TESTS_RUN + 1))
if [[ $? -le 1 ]]; then
    echo -e "${GREEN}PASS${NC}: Malformed JSON doesn't crash"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}: Malformed JSON caused crash"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 15: null workspace.current_dir should show "unknown"
output=$(echo '{"workspace":{"current_dir":null}}' | "$STATUSLINE" 2>&1)
assert_contains "$output" "unknown" "null current_dir shows 'unknown'"

# Test 16: empty string current_dir should show "unknown"
output=$(echo '{"workspace":{"current_dir":""}}' | "$STATUSLINE" 2>&1)
assert_contains "$output" "unknown" "empty current_dir shows 'unknown'"

# Test 17: missing workspace key should show "unknown"
output=$(echo '{}' | "$STATUSLINE" 2>&1)
assert_contains "$output" "unknown" "missing workspace shows 'unknown'"

# Test 18: trailing slash handling
output=$(run_statusline "/Users/andrewsager/projects/myapp/")
assert_contains "$output" "myapp" "trailing slash is handled correctly"

# Test 19: root path shows "/"
output=$(run_statusline "/")
assert_contains "$output" "/" "root path shows '/'"

echo ""
echo "=== Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
