#!/bin/bash

# Comprehensive test script for ed macro functionality
# Tests both space insertion (ESC+number) and macro expansion (ESC+letters)

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    echo -e "${YELLOW}Running test: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command"; then
        local actual_exit_code=$?
        if [ $actual_exit_code -eq $expected_exit_code ]; then
            echo -e "${GREEN}✓ PASS: $test_name${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL: $test_name (exit code $actual_exit_code, expected $expected_exit_code)${NC}"
        fi
    else
        local actual_exit_code=$?
        if [ $actual_exit_code -eq $expected_exit_code ]; then
            echo -e "${GREEN}✓ PASS: $test_name${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAIL: $test_name (exit code $actual_exit_code, expected $expected_exit_code)${NC}"
        fi
    fi
    echo
}

# Function to test no segfault
test_no_segfault() {
    local test_name="$1"
    local test_input="$2"
    
    echo -e "${YELLOW}Testing no segfault: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Create a test file
    echo "test content line 1" > test_input.txt
    echo "test content line 2" >> test_input.txt
    
    # Run the test and capture exit code
    printf "%s" "$test_input" | timeout 5s ./ed test_input.txt >/dev/null 2>&1
    local exit_code=$?
    
    # Exit code 139 indicates segfault, 124 indicates timeout
    if [ $exit_code -eq 139 ]; then
        echo -e "${RED}✗ FAIL: $test_name (SEGMENTATION FAULT)${NC}"
    elif [ $exit_code -eq 124 ]; then
        echo -e "${RED}✗ FAIL: $test_name (TIMEOUT - likely hung)${NC}"
    else
        echo -e "${GREEN}✓ PASS: $test_name (no segfault, exit code $exit_code)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    
    # Cleanup
    rm -f test_input.txt
    echo
}

# Function to test space insertion
test_space_insertion() {
    local count="$1"
    echo -e "${YELLOW}Testing space insertion: ESC+$count${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Create a test to insert spaces in insert mode
    echo "test line" > test_spaces.txt
    
    # Test inserting spaces using ESC+number in insert mode
    # We'll use 'i' command to enter insert mode, then ESC+number, then '.' to exit insert mode
    local test_input="test_spaces.txt\ni\nHello\x1b${count}World\n.\nwq"
    
    printf "%s" "$test_input" | ./ed >/dev/null 2>&1
    local exit_code=$?
    
    if [ $exit_code -eq 139 ]; then
        echo -e "${RED}✗ FAIL: Space insertion ESC+$count (SEGMENTATION FAULT)${NC}"
    else
        # Check if the file contains the expected spaces
        if [ -f test_spaces.txt ]; then
            # Look for the pattern: Hello + spaces + World
            local expected_spaces=""
            for ((i=0; i<count; i++)); do
                expected_spaces="$expected_spaces "
            done
            
            if grep -q "Hello${expected_spaces}World" test_spaces.txt; then
                echo -e "${GREEN}✓ PASS: Space insertion ESC+$count${NC}"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "${RED}✗ FAIL: Space insertion ESC+$count (spaces not found in output)${NC}"
                echo "File contents:"
                cat test_spaces.txt
            fi
        else
            echo -e "${RED}✗ FAIL: Space insertion ESC+$count (output file not created)${NC}"
        fi
    fi
    
    rm -f test_spaces.txt
    echo
}

echo -e "${GREEN}=== Ed Macro System Test Suite ===${NC}"
echo

# First, rebuild ed to ensure we have the latest version
echo -e "${YELLOW}Building ed...${NC}"
run_test "Build ed" "make clean >/dev/null 2>&1 && make >/dev/null 2>&1"

# Test basic functionality first
echo -e "${GREEN}=== Basic Functionality Tests ===${NC}"
run_test "Basic ed startup" "echo 'q' | ./ed >/dev/null 2>&1"

# Test that ed can load and quit with a file
run_test "Load file and quit" "echo 'test' > temp.txt && echo 'q' | ./ed temp.txt >/dev/null 2>&1; rm -f temp.txt"

# Test segfault scenarios
echo -e "${GREEN}=== Segfault Prevention Tests ===${NC}"

# Test the original problematic sequences
test_no_segfault "ESC+gs macro" "335\n\x1bgs\nq"
test_no_segfault "ESC+p macro" "1\n\x1bp\nq"

# Test other macro sequences
test_no_segfault "ESC+gd macro" "1\n\x1bgd\nq"
test_no_segfault "ESC+ga macro" "1\n\x1bga\nq"
test_no_segfault "ESC+gc macro" "1\n\x1bgc\nq"
test_no_segfault "ESC+gp macro" "1\n\x1bgp\nq"
test_no_segfault "ESC+gl macro" "1\n\x1bgl\nq"

# Test nonexistent macros
test_no_segfault "ESC+nonexistent macro" "1\n\x1bxyz\nq"

# Test space insertion functionality
echo -e "${GREEN}=== Space Insertion Tests ===${NC}"

# Test various space counts
test_space_insertion "5"
test_space_insertion "10"
test_space_insertion "1"
test_space_insertion "20"

# Test edge cases for space insertion
echo -e "${YELLOW}Testing edge case: ESC+0${NC}"
TESTS_RUN=$((TESTS_RUN + 1))
echo "test" > test_zero.txt
echo -e "test_zero.txt\ni\nHello\x1b0World\n.\nwq" | ./ed >/dev/null 2>&1
if [ $? -ne 139 ]; then
    echo -e "${GREEN}✓ PASS: ESC+0 (no segfault)${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: ESC+0 (segfault)${NC}"
fi
rm -f test_zero.txt
echo

# Test mixed scenarios
echo -e "${GREEN}=== Mixed Scenario Tests ===${NC}"

test_no_segfault "ESC+number then ESC+letter" "1\ni\n\x1b5\x1bp\n.\nq"
test_no_segfault "Multiple ESC sequences" "1\n\x1bgs\n\x1bp\n\x1bgd\nq"

# Test macro system with actual file operations
echo -e "${GREEN}=== Macro Integration Tests ===${NC}"

echo -e "${YELLOW}Testing git status macro (if available)${NC}"
TESTS_RUN=$((TESTS_RUN + 1))
echo "# Test file" > test_git.txt
echo -e "test_git.txt\n\x1bgs\nq" | timeout 10s ./ed >/dev/null 2>&1
if [ $? -ne 139 ]; then
    echo -e "${GREEN}✓ PASS: Git status macro (no segfault)${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: Git status macro (segfault)${NC}"
fi
rm -f test_git.txt
echo

# Final summary
echo -e "${GREEN}=== Test Summary ===${NC}"
echo -e "Tests run: $TESTS_RUN"
echo -e "Tests passed: $TESTS_PASSED"
echo -e "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed.${NC}"
    exit 1
fi
