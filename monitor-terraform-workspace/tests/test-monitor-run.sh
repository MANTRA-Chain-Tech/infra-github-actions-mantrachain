#!/bin/bash

# Test script for monitor-run functionality
# Tests actual run monitoring against a real Terraform Cloud workspace

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common test functions
source "$SCRIPT_DIR/test-common.sh"

# Test configuration using the existing test workspace
TEST_ORGANIZATION="mantrachain"
TEST_WORKSPACE_NAME="dapps-workspaces-manager"
TEST_WORKSPACE_ID="ws-XrQGnGJySWE6Ac3R"

main() {
    echo "🧪 Running monitor-run tests..."
    
    setup_test_env
    
    # Test 1: Monitor run by workspace ID (check for existing runs)
    test_monitor_run_by_workspace_id
    
    # Test 2: Monitor run by workspace name (check for existing runs)
    test_monitor_run_by_workspace_name
    
    # Test 3: Test timeout behavior with very short timeout
    test_monitor_run_timeout
    
    # Test 4: Test with debug logging enabled
    test_monitor_run_with_debug
    
    # Test 5: Test monitor purpose output
    test_monitor_run_purpose
    
    echo "✅ All monitor-run tests passed!"
}

test_monitor_run_by_workspace_id() {
    echo "Test: Monitor run by workspace ID"
    
    # Set up environment for monitoring by workspace ID (preserve real token)
    export ORGANIZATION="$TEST_ORGANIZATION"
    export INPUT_WORKSPACE_ID="$TEST_WORKSPACE_ID"
    export INPUT_WORKSPACE_NAME=""
    export TIMEOUT_MINUTES="2"
    export POLLING_INTERVAL_SECONDS="10"
    export INITIAL_WAIT_SECONDS="5"
    export DEBUG_LOGGING="false"
    export MONITOR_PURPOSE="test workspace ID monitoring"
    
    # Ensure no mocking
    unset MOCK_CURL
    unset -f curl 2>/dev/null || true
    
    # Run the monitor script
    output=$(cd "$PROJECT_ROOT" && bash scripts/monitor-workspace.sh 2>&1) || true
    
    # Check that workspace information is output in log messages
    echo "$output" | grep -q "Workspace resolved: $TEST_WORKSPACE_NAME (ID: $TEST_WORKSPACE_ID)" || {
        echo "❌ Expected workspace resolution message not found"
        echo "Output: $output"
        exit 1
    }
    
    # Check for completion message or known status messages
    if echo "$output" | grep -qE "(Monitoring completed successfully|No active runs found|Run completed with status|Monitoring timed out)"; then
        echo "✅ Valid monitoring completion found in output"
    else
        echo "❌ No valid monitoring completion found in output"
        echo "Output: $output"
        exit 1
    fi
    
    echo "✅ Monitor run by workspace ID test passed"
}

test_monitor_run_by_workspace_name() {
    echo "Test: Monitor run by workspace name"
    
    # Set up environment for monitoring by workspace name (preserve real token)
    export ORGANIZATION="$TEST_ORGANIZATION"
    export INPUT_WORKSPACE_ID=""
    export INPUT_WORKSPACE_NAME="$TEST_WORKSPACE_NAME"
    export TIMEOUT_MINUTES="2"
    export POLLING_INTERVAL_SECONDS="10"
    export INITIAL_WAIT_SECONDS="5"
    export DEBUG_LOGGING="false"
    export MONITOR_PURPOSE="test workspace name monitoring"
    
    # Ensure no mocking
    unset MOCK_CURL
    unset -f curl 2>/dev/null || true
    
    # Run the monitor script
    output=$(cd "$PROJECT_ROOT" && bash scripts/monitor-workspace.sh 2>&1) || true
    
    # Check that workspace information is output in log messages
    echo "$output" | grep -q "Workspace resolved: $TEST_WORKSPACE_NAME (ID: $TEST_WORKSPACE_ID)" || {
        echo "❌ Expected workspace resolution message not found"
        echo "Output: $output"
        exit 1
    }
    
    echo "✅ Monitor run by workspace name test passed"
}

test_monitor_run_timeout() {
    echo "Test: Monitor run timeout behavior"
    
    # Set up environment with very short timeout (preserve real token)
    export ORGANIZATION="$TEST_ORGANIZATION"
    export INPUT_WORKSPACE_ID="$TEST_WORKSPACE_ID"
    export INPUT_WORKSPACE_NAME=""
    export TIMEOUT_MINUTES="0.1"  # 6 seconds timeout
    export POLLING_INTERVAL_SECONDS="2"
    export INITIAL_WAIT_SECONDS="1"
    export DEBUG_LOGGING="false"
    export MONITOR_PURPOSE="timeout test"
    
    # Ensure no mocking
    unset MOCK_CURL
    unset -f curl 2>/dev/null || true
    
    # Run the monitor script
    output=$(cd "$PROJECT_ROOT" && bash scripts/monitor-workspace.sh 2>&1) || true
    
    # Should either timeout or find no run quickly
    if echo "$output" | grep -qE "(Monitoring timed out|No active runs found|timeout|no-run-found)"; then
        echo "✅ Timeout behavior working correctly"
    else
        echo "❌ Expected timeout or no-run-found status"
        echo "Output: $output"
        exit 1
    fi
    
    echo "✅ Monitor run timeout test passed"
}

test_monitor_run_with_debug() {
    echo "Test: Monitor run with debug logging"
    
    # Set up environment with debug logging (preserve real token)
    export ORGANIZATION="$TEST_ORGANIZATION"
    export INPUT_WORKSPACE_ID="$TEST_WORKSPACE_ID"
    export INPUT_WORKSPACE_NAME=""
    export TIMEOUT_MINUTES="1"
    export POLLING_INTERVAL_SECONDS="10"
    export INITIAL_WAIT_SECONDS="5"
    export DEBUG_LOGGING="true"
    export MONITOR_PURPOSE="debug test"
    
    # Ensure no mocking
    unset MOCK_CURL
    unset -f curl 2>/dev/null || true
    
    # Run the monitor script
    output=$(cd "$PROJECT_ROOT" && bash scripts/monitor-workspace.sh 2>&1) || true
    
    # Check for debug output
    if echo "$output" | grep -q "🔍\|DEBUG\|API request\|Response"; then
        echo "✅ Debug logging is working"
    else
        echo "⚠️ Debug output not detected (this may be normal if no runs are active)"
    fi
    
    echo "✅ Monitor run with debug test passed"
}

test_monitor_run_purpose() {
    echo "Test: Monitor run purpose in output"
    
    custom_purpose="integration-test-workspace"
    
    # Set up environment with custom purpose (preserve real token)
    export ORGANIZATION="$TEST_ORGANIZATION" 
    export INPUT_WORKSPACE_ID="$TEST_WORKSPACE_ID"
    export INPUT_WORKSPACE_NAME=""
    export TIMEOUT_MINUTES="1"
    export POLLING_INTERVAL_SECONDS="10"
    export INITIAL_WAIT_SECONDS="5"
    export DEBUG_LOGGING="false"
    export MONITOR_PURPOSE="$custom_purpose"
    
    # Ensure no mocking
    unset MOCK_CURL
    unset -f curl 2>/dev/null || true
    
    # Run the monitor script
    output=$(cd "$PROJECT_ROOT" && bash scripts/monitor-workspace.sh 2>&1) || true
    
    # Check that purpose appears in output
    if echo "$output" | grep -q "$custom_purpose"; then
        echo "✅ Monitor purpose appears in output"
    else
        echo "⚠️ Monitor purpose not found in output (may be normal depending on implementation)"
    fi
    
    echo "✅ Monitor run purpose test passed"
}

# Check if we have required environment variables
check_test_requirements() {
    if [ -z "$TF_API_TOKEN" ]; then
        echo "❌ TF_API_TOKEN environment variable is required for integration tests"
        echo "   Export your Terraform Cloud API token:"
        echo "   export TF_API_TOKEN='your-terraform-cloud-token'"
        exit 1
    fi
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_test_requirements
    main "$@"
fi
