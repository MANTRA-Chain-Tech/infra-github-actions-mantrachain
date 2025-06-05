#!/bin/bash

# Test utilities and helpers

# Test framework variables
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Colors for test output
readonly TEST_GREEN='\033[0;32m'
readonly TEST_RED='\033[0;31m'
readonly TEST_NC='\033[0m'

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        PASSED_COUNT=$((PASSED_COUNT + 1))
        echo -e "${TEST_GREEN}✓${TEST_NC} Test $TEST_COUNT: PASS ${message:+- $message}"
        return 0
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo -e "${TEST_RED}✗${TEST_NC} Test $TEST_COUNT: FAIL ${message:+- $message}"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [[ -n "$value" ]]; then
        PASSED_COUNT=$((PASSED_COUNT + 1))
        echo -e "${TEST_GREEN}✓${TEST_NC} Test $TEST_COUNT: PASS ${message:+- $message}"
        return 0
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo -e "${TEST_RED}✗${TEST_NC} Test $TEST_COUNT: FAIL ${message:+- $message}"
        echo -e "  Expected: non-empty value"
        echo -e "  Actual:   empty"
        return 1
    fi
}

assert_command_exists() {
    local command="$1"
    local message="${2:-}"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if command -v "$command" >/dev/null 2>&1; then
        PASSED_COUNT=$((PASSED_COUNT + 1))
        echo -e "${TEST_GREEN}✓${TEST_NC} Test $TEST_COUNT: PASS ${message:+- $message}"
        return 0
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo -e "${TEST_RED}✗${TEST_NC} Test $TEST_COUNT: FAIL ${message:+- $message}"
        echo -e "  Command '$command' not found"
        return 1
    fi
}

# Test result summary
print_test_summary() {
    echo
    echo "=================================="
    echo "Test Summary"
    echo "=================================="
    echo -e "Total tests: $TEST_COUNT"
    echo -e "${TEST_GREEN}Passed: $PASSED_COUNT${TEST_NC}"
    echo -e "${TEST_RED}Failed: $FAILED_COUNT${TEST_NC}"
    
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo -e "${TEST_GREEN}All tests passed!${TEST_NC}"
        return 0
    else
        echo -e "${TEST_RED}Some tests failed!${TEST_NC}"
        return 1
    fi
}

# Mock curl function - only used for unit tests
mock_curl() {
    local args=("$@")
    local url=""
    local method="GET"
    
    # Extract URL and method from arguments
    for i in "${!args[@]}"; do
        local arg="${args[$i]}"
        if [[ "$arg" =~ ^https:// ]]; then
            url="$arg"
        elif [[ "$arg" == "-X" ]] && [[ $((i+1)) -lt ${#args[@]} ]]; then
            method="${args[$((i+1))]}"
        fi
    done
    
    if [[ "${DEBUG_LOGGING:-}" == "true" ]]; then
        echo "Mock curl called: $method $url" >&2
    fi
    
    # Return mock responses based on URL patterns
    if [[ "$url" =~ /workspaces/ws-test123$ ]]; then
        echo '{"data":{"id":"ws-test123","attributes":{"name":"test-workspace"}}}'
        return 0
    elif [[ "$url" =~ /organizations/test-org/workspaces/test-workspace$ ]]; then
        echo '{"data":{"id":"ws-test123","attributes":{"name":"test-workspace"}}}'
        return 0
    elif [[ "$url" =~ /workspaces/ws-test123/runs ]]; then
        echo '{"data":[{"id":"run-test123","attributes":{"status":"applied","created-at":"2023-01-01T00:00:00Z","source":"api"}}]}'
        return 0
    else
        if [[ "${DEBUG_LOGGING:-}" == "true" ]]; then
            echo "Mock curl: No mock response for URL: $url" >&2
        fi
        echo '{"errors":[{"detail":"Not found"}]}'
        return 1
    fi
}

# Setup test environment for unit tests (with mocking)
setup_mock_test_env() {
    export TF_API_TOKEN="test-token"
    export ORGANIZATION="test-org"
    export DEBUG_LOGGING="${DEBUG_LOGGING:-false}"
    export MOCK_CURL="true"
    
    # Override curl with mock function
    curl() {
        mock_curl "$@"
    }
    export -f curl
}

# Setup test environment for integration tests (no mocking)
setup_test_env() {
    # Don't override TF_API_TOKEN if it's already set (for integration tests)
    if [[ -z "${TF_API_TOKEN:-}" ]]; then
        export TF_API_TOKEN="test-token"
    fi
    
    # Don't override ORGANIZATION if it's already set (for integration tests)  
    if [[ -z "${ORGANIZATION:-}" ]]; then
        export ORGANIZATION="test-org"
    fi
    
    export DEBUG_LOGGING="${DEBUG_LOGGING:-false}"
    
    # Ensure no mocking for integration tests
    unset MOCK_CURL
    
    # Remove any curl function override
    unset -f curl 2>/dev/null || true
}

# Cleanup test environment
cleanup_test_env() {
    unset TF_API_TOKEN ORGANIZATION DEBUG_LOGGING MOCK_CURL
    unset -f curl 2>/dev/null || true
}
