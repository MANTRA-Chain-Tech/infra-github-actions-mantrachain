#!/usr/bin/env bats

# Integration tests using real Cloudflare API
# Requires CLOUDFLARE_API_TOKEN environment variable to be set

# Configuration
readonly MANTRACHAIN_POLICIES="1a3e0a22-040d-4941-a899-a370548e5bd5:1,66f03940-062b-4d65-9c32-7c714ac89194:2"

# Function to verify API token
verify_token() {
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/tokens/verify" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '"success":true'; then
        return 0
    else
        echo "Token verification failed: $response" >&2
        return 1
    fi
}

setup_file() {
    # Set account ID first
    export CLOUDFLARE_ACCOUNT_ID="2ff8e4962cfd414617e13d4c503e09ae"
    
    # Check that API token exists
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        echo "CLOUDFLARE_API_TOKEN environment variable not set" >&2
        exit 1
    fi
    
    # Verify token is valid before running any tests
    if ! verify_token; then
        echo "CLOUDFLARE_API_TOKEN is invalid or expired" >&2
        exit 1
    fi
    
    echo "✓ Cloudflare API token validated successfully"
}

setup() {
    # Use real Cloudflare account ID (already set in setup_file)
    export CLOUDFLARE_ACCOUNT_ID="2ff8e4962cfd414617e13d4c503e09ae"
    
    # Source the script to load functions
    source "${BATS_TEST_DIRNAME}/../main.sh"
    
    # Test domain for integration tests
    export TEST_DOMAIN="placeholder-for-running-integration-test.mzone.dev"
    export TEST_APP_NAME="Integration Test App"
}

teardown() {
    # Cleanup: always try to delete test app after each test
    if [ -n "$CLOUDFLARE_API_TOKEN" ] && [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
        delete_app "$TEST_DOMAIN" >/dev/null 2>&1 || true
    fi
}

@test "integration: token verification works" {
    # Test that our token verification function works
    run verify_token
    [ "$status" -eq 0 ]
}

@test "integration: create app with real API (idempotent)" {
    # First ensure app doesn't exist (delete if it does)
    delete_app "$TEST_DOMAIN"
    
    # Verify app doesn't exist before creation
    result=$(check_app_exists "$TEST_DOMAIN")
    [ -z "$result" ]
    
    # Create the app (with MantraChain policies)
    run create_app "$TEST_APP_NAME" "$TEST_DOMAIN" "$MANTRACHAIN_POLICIES"
    [ "$status" -eq 0 ]
    [[ "$output" != "" ]]
    
    # Store the app ID (last line of output)
    app_id=$(echo "$output" | tail -n1)
    
    # Verify app was created by checking it exists
    result=$(check_app_exists "$TEST_DOMAIN")
    [ "$result" = "$app_id" ]
}

@test "integration: create app when it already exists (idempotent)" {
    # First create an app
    run create_app "$TEST_APP_NAME" "$TEST_DOMAIN" "$MANTRACHAIN_POLICIES"
    [ "$status" -eq 0 ]
    app_id1=$(echo "$output" | tail -n1)
    [ -n "$app_id1" ]
    
    # Create again (should delete and recreate)
    run create_app "$TEST_APP_NAME" "$TEST_DOMAIN" "$MANTRACHAIN_POLICIES"
    [ "$status" -eq 0 ]
    [[ "$output" != "" ]]
    
    app_id2=$(echo "$output" | tail -n1)
    
    # App IDs should be different (recreated)
    [ "$app_id1" != "$app_id2" ]
    
    # Verify new app exists
    result=$(check_app_exists "$TEST_DOMAIN")
    [ "$result" = "$app_id2" ]
}

@test "integration: delete existing app" {
    # First create an app
    output=$(create_app "$TEST_APP_NAME" "$TEST_DOMAIN" "$MANTRACHAIN_POLICIES" 2>&1)
    app_id=$(echo "$output" | tail -n1)
    [ -n "$app_id" ]
    
    # Verify it exists
    result=$(check_app_exists "$TEST_DOMAIN")
    [ "$result" = "$app_id" ]
    
    # Delete the app
    run delete_app "$TEST_DOMAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Application deleted successfully"* ]]
    
    # Verify it no longer exists
    result=$(check_app_exists "$TEST_DOMAIN")
    [ -z "$result" ]
}

@test "integration: delete non-existent app (idempotent)" {
    # Ensure app doesn't exist
    delete_app "$TEST_DOMAIN"
    
    # Verify it doesn't exist
    result=$(check_app_exists "$TEST_DOMAIN")
    [ -z "$result" ]
    
    # Try to delete non-existent app
    run delete_app "$TEST_DOMAIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No application found"* ]]
}

@test "integration: main function create action" {
    # Ensure clean state
    delete_app "$TEST_DOMAIN"
    
    # Test main function create with MantraChain policies
    run main --action create --name "$TEST_APP_NAME" --domain "$TEST_DOMAIN" --policies "$MANTRACHAIN_POLICIES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"App ID:"* ]]
    
    # Verify app was created
    result=$(check_app_exists "$TEST_DOMAIN")
    [ -n "$result" ]
}

@test "integration: main function delete action" {
    # First create an app
    output=$(create_app "$TEST_APP_NAME" "$TEST_DOMAIN" "$MANTRACHAIN_POLICIES" 2>&1)
    app_id=$(echo "$output" | tail -n1)
    [ -n "$app_id" ]
    
    # Test main function delete
    run main --action delete --name "$TEST_APP_NAME" --domain "$TEST_DOMAIN"
    [ "$status" -eq 0 ]
    
    # Verify app was deleted
    result=$(check_app_exists "$TEST_DOMAIN")
    [ -z "$result" ]
}

@test "integration: main function with custom policies" {
    # Ensure clean state
    delete_app "$TEST_DOMAIN"
    
    # Test with custom policies (using defined MantraChain policy IDs)
    run main --action create --name "$TEST_APP_NAME" --domain "$TEST_DOMAIN" --policies "$MANTRACHAIN_POLICIES"
    [ "$status" -eq 0 ]
    [[ "$output" == *"App ID:"* ]]
    
    # Verify app was created
    result=$(check_app_exists "$TEST_DOMAIN")
    [ -n "$result" ]
}

@test "integration: check_app_exists with real API" {
    # Test with non-existent app
    result=$(check_app_exists "nonexistent-$(date +%s).mantrachain.io")
    [ -z "$result" ]
    
    # Create an app and test existence
    output=$(create_app "$TEST_APP_NAME" "$TEST_DOMAIN" "$MANTRACHAIN_POLICIES" 2>&1)
    app_id=$(echo "$output" | tail -n1)
    [ -n "$app_id" ]
    
    result=$(check_app_exists "$TEST_DOMAIN")
    [ "$result" = "$app_id" ]
}