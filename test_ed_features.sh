#!/bin/bash

# Comprehensive test script for ed features
# Tests macro functionality, space insertion, and prevents regression

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing Ed Features - Macro System and Space Insertion${NC}"
echo "============================================================"

# Test directory
TEST_DIR="/tmp/ed_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Counter for tests
TESTS_PASSED=0
TESTS_TOTAL=0

test_result() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
    fi
}

# Test 1: Basic ed functionality with file argument
echo
echo "Test 1: Basic ed functionality"
echo "test line 1" > test1.txt

result=$(echo "1p" | ed test1.txt 2>/dev/null)
if echo "$result" | grep -q "test line 1"; then
    test_result 0 "Basic file loading and printing"
else
    test_result 1 "Basic file loading and printing"
fi

# Test 2: Space insertion with ESC sequences
echo
echo "Test 2: Space insertion functionality"
echo "" > test2.txt

# Test ESC+5 (should insert 5 spaces)
printf "a\nstart\0335end\n.\nw\nq\n" | ed test2.txt > /dev/null 2>&1
result=$(cat test2.txt | grep "start     end")
if [ -n "$result" ]; then
    test_result 0 "ESC+5 space insertion"
else
    test_result 1 "ESC+5 space insertion"
fi

# Test 3: Different space counts
echo
echo "Test 3: Various space insertion counts"
echo "" > test3.txt

printf "a\nA\0333B\03310C\n.\nw\nq\n" | ed test3.txt > /dev/null 2>&1
# Should have: A + 3 spaces + B + 10 spaces + C = 13 spaces total
# Count just the spaces, not total characters  
actual_spaces=$(cat test3.txt | tr -cd ' ' | wc -c)
if [ "$actual_spaces" -eq 13 ]; then
    test_result 0 "Multiple space insertions (3 and 10 spaces)"
else
    test_result 1 "Multiple space insertions (expected 13 spaces, got $actual_spaces spaces)"
fi

# Test 4: Macro functionality (no segfault test)
echo
echo "Test 4: Macro system functionality"

# Create a simple test macro
echo "test:!echo macro_works" > ~/.ed_macros

# Test if macro expansion works without crashing
echo "content" > test4.txt

# Run with timeout to prevent hanging, check for segfault
timeout 5s sh -c 'printf "\033test\nq\n" | ed test4.txt' > output4.txt 2>&1
exit_code=$?

# Check if ed didn't crash (exit code 139 = segfault)
if [ $exit_code -ne 139 ] && [ $exit_code -ne 124 ]; then  # 124 = timeout
    test_result 0 "Macro system doesn't crash"
else
    if [ $exit_code -eq 139 ]; then
        test_result 1 "Macro system crashes with segfault"
    else
        test_result 1 "Macro system timeout or other error"
    fi
fi

# Test 5: Complex macro functionality
echo
echo "Test 5: Complex macro functionality"

# Create a more complex macro
echo "gs:!echo 'On branch main'" > ~/.ed_macros

timeout 5s sh -c 'printf "\033gs\nq\n" | ed test4.txt' > output5.txt 2>&1
exit_code=$?

if [ $exit_code -ne 139 ]; then
    test_result 0 "Complex macro execution (no crash)"
else
    test_result 1 "Complex macro execution (segfault)"
fi

# Test 6: Edge cases for space insertion
echo
echo "Test 6: Edge cases for space insertion"

# Test with 0 spaces (ESC+0 should insert 0 spaces)
echo "" > test6.txt
printf "a\nX\0330Y\n.\nw\nq\n" | ed test6.txt > /dev/null 2>&1
result=$(cat test6.txt | tr -d '\n')  # Remove newline for comparison
if [ "$result" = "XY" ]; then
    test_result 0 "ESC+0 (no spaces inserted)"
else
    test_result 1 "ESC+0 handling (got: '$result', expected: 'XY')"
fi

# Test 7: Large space count (should be limited)
echo
echo "Test 7: Large space count safety"
echo "" > test7.txt

printf "a\nstart\033999end\n.\nw\nq\n" | ed test7.txt > /dev/null 2>&1
spaces_count=$(cat test7.txt | tr -cd ' ' | wc -c)
if [ "$spaces_count" -le 100 ]; then
    test_result 0 "Large space count is limited (safety feature) - got $spaces_count spaces"
else
    test_result 1 "Large space count not properly limited - got $spaces_count spaces"
fi

# Test 8: ESC followed by non-digit
echo
echo "Test 8: ESC followed by non-digit (should treat ESC literally)"
echo "" > test8.txt

printf "a\nstart\033xend\n.\nw\nq\n" | ed test8.txt > /dev/null 2>&1
# Should contain ESC character followed by 'x'
if hexdump -C test8.txt | grep -q "1b 78"; then  # 1b = ESC, 78 = 'x'
    test_result 0 "ESC+non-digit treated literally"
else
    test_result 1 "ESC+non-digit not handled correctly"
fi

# Test 9: Multiple digit space insertion
echo
echo "Test 9: Multiple digit numbers"
echo "" > test9.txt

printf "a\nX\03325Y\n.\nw\nq\n" | ed test9.txt > /dev/null 2>&1
spaces_count=$(cat test9.txt | tr -cd ' ' | wc -c)
if [ "$spaces_count" -eq 25 ]; then
    test_result 0 "ESC+25 (two digit number) works correctly"
else
    test_result 1 "ESC+25 failed - got $spaces_count spaces instead of 25"
fi

# Restore original macros if they existed
cp ~/.ed_macros.backup ~/.ed_macros 2>/dev/null || true

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo
echo "============================================================"
echo -e "${YELLOW}Test Results Summary${NC}"
echo "============================================================"
if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}All tests passed! ($TESTS_PASSED/$TESTS_TOTAL)${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. ($TESTS_PASSED/$TESTS_TOTAL passed)${NC}"
    exit 1
fi
