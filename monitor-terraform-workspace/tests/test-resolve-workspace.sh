#!/bin/bash
set -euo pipefail

# Test script for resolve-workspace.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")/scripts"

# shellcheck source=./test-common.sh
source "$SCRIPT_DIR/test-common.sh"

# Test workspace resolution functions
test_resolve_workspace() {
    echo "Testing workspace resolution..."
    
    # Check if token is provided
    if [[ -z "${TF_API_TOKEN:-}" ]]; then
        echo "ERROR: TF_API_TOKEN must be set to run tests"
        echo "Please export TF_API_TOKEN with a valid Terraform Cloud API token"
        exit 1
    fi
    
    # Set up test environment with real workspace
    export ORGANIZATION="mantrachain"
    local TEST_WORKSPACE_ID="ws-XrQGnGJySWE6Ac3R"
    local TEST_WORKSPACE_NAME="dapps-workspaces-manager"
    
    # Test 1: resolve workspace by ID
    echo "  Test case: Resolve workspace by ID"
    export INPUT_WORKSPACE_ID="$TEST_WORKSPACE_ID"
    export INPUT_WORKSPACE_NAME=""
    
    local output
    local exit_code=0
    
    if [[ "${DEBUG_LOGGING:-}" == "true" ]]; then
        echo "Running: $SCRIPTS_DIR/resolve-workspace.sh"
        echo "Environment: TF_API_TOKEN=<redacted>, ORGANIZATION=$ORGANIZATION"
        echo "Inputs: INPUT_WORKSPACE_ID=$INPUT_WORKSPACE_ID, INPUT_WORKSPACE_NAME=$INPUT_WORKSPACE_NAME"
    fi
    
    if output=$("$SCRIPTS_DIR/resolve-workspace.sh" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ "${DEBUG_LOGGING:-}" == "true" ]]; then
        echo "Script exit code: $exit_code"
        echo "Script output:"
        echo "$output"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        assert_equals "WORKSPACE_ID=$TEST_WORKSPACE_ID" "$(echo "$output" | grep "^WORKSPACE_ID=" || echo "NOT_FOUND")" "Resolve by ID - workspace ID output"
        assert_equals "WORKSPACE_NAME=$TEST_WORKSPACE_NAME" "$(echo "$output" | grep "^WORKSPACE_NAME=" || echo "NOT_FOUND")" "Resolve by ID - workspace name output"
    else
        echo "Script output: $output"
        assert_equals "0" "$exit_code" "Resolve by ID - script should have succeeded"
    fi
    
    # Test 2: resolve workspace by name
    echo "  Test case: Resolve workspace by name"
    export INPUT_WORKSPACE_ID=""
    export INPUT_WORKSPACE_NAME="$TEST_WORKSPACE_NAME"
    
    if output=$("$SCRIPTS_DIR/resolve-workspace.sh" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ "${DEBUG_LOGGING:-}" == "true" ]]; then
        echo "Script exit code: $exit_code"
        echo "Script output:"
        echo "$output"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        assert_equals "WORKSPACE_ID=$TEST_WORKSPACE_ID" "$(echo "$output" | grep "^WORKSPACE_ID=" || echo "NOT_FOUND")" "Resolve by name - workspace ID output"
        assert_equals "WORKSPACE_NAME=$TEST_WORKSPACE_NAME" "$(echo "$output" | grep "^WORKSPACE_NAME=" || echo "NOT_FOUND")" "Resolve by name - workspace name output"
    else
        echo "Script output: $output"
        assert_equals "0" "$exit_code" "Resolve by name - script should have succeeded"
    fi
}

# Test validation
test_validation() {
    echo "Testing input validation..."
    
    # Save original token
    local original_token="${TF_API_TOKEN:-}"
    
    # Test 1: missing required environment variables
    echo "  Test case: Missing required environment variables"
    unset TF_API_TOKEN ORGANIZATION || true
    
    local exit_code=0
    "$SCRIPTS_DIR/resolve-workspace.sh" 2>/dev/null || exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        assert_equals "1" "0" "Missing env vars - script should fail with missing TF_API_TOKEN/ORGANIZATION"
    else
        assert_equals "0" "0" "Missing env vars - script correctly failed with missing TF_API_TOKEN/ORGANIZATION"
    fi
    
    # Restore token for next tests
    export TF_API_TOKEN="$original_token"
    export ORGANIZATION="mantrachain"
    
    # Test 2: missing workspace inputs
    echo "  Test case: Missing workspace inputs"
    export INPUT_WORKSPACE_ID=""
    export INPUT_WORKSPACE_NAME=""
    
    exit_code=0
    "$SCRIPTS_DIR/resolve-workspace.sh" 2>/dev/null || exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        assert_equals "1" "0" "Missing workspace inputs - script should fail with missing workspace ID/name"
    else
        assert_equals "0" "0" "Missing workspace inputs - script correctly failed with missing workspace ID/name"
    fi
}

# Debug function to check script existence
check_script_exists() {
    echo "Checking script existence..."
    if [[ ! -f "$SCRIPTS_DIR/resolve-workspace.sh" ]]; then
        echo "ERROR: resolve-workspace.sh not found at $SCRIPTS_DIR/resolve-workspace.sh"
        echo "Available files in $SCRIPTS_DIR:"
        ls -la "$SCRIPTS_DIR" 2>/dev/null || echo "Directory not found"
        return 1
    fi
    
    if [[ ! -x "$SCRIPTS_DIR/resolve-workspace.sh" ]]; then
        echo "WARNING: resolve-workspace.sh is not executable"
        chmod +x "$SCRIPTS_DIR/resolve-workspace.sh"
    fi
    
    echo "Script found and is executable"
    return 0
}

# Run tests
main() {
    echo "Running resolve-workspace tests..."
    echo "Script directory: $SCRIPTS_DIR"
    
    # Check if token is provided
    if [[ -z "${TF_API_TOKEN:-}" ]]; then
        echo ""
        echo "ERROR: TF_API_TOKEN environment variable is required to run tests"
        echo "Tests use the real Terraform Cloud API with the following workspace:"
        echo "  Organization: mantrachain"
        echo "  Workspace: dapps-workspaces-manager (ID: ws-XrQGnGJySWE6Ac3R)"
        echo ""
        echo "Please export TF_API_TOKEN with a valid token that has access to this workspace"
        exit 1
    fi
    
    # Enable debug logging for troubleshooting
    if [[ "${1:-}" == "--debug" ]]; then
        export DEBUG_LOGGING="true"
        echo "Debug logging enabled"
    fi
    
    echo
    
    if ! check_script_exists; then
        echo "Cannot run tests - script not found"
        exit 1
    fi
    
    test_validation
    test_resolve_workspace
    
    print_test_summary
}

main "$@"
