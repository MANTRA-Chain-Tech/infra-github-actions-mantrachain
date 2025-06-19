#!/usr/bin/env bats

# Setup test environment
setup() {
    # Create a temporary directory for test files
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    
    # Source the script under test
    source "${BATS_TEST_DIRNAME}/../extract-package-info.sh"
    
    # Mock GITHUB_OUTPUT for testing
    export GITHUB_OUTPUT="$TEST_DIR/github_output"
    touch "$GITHUB_OUTPUT"
}

# Cleanup after each test
teardown() {
    rm -rf "$TEST_DIR"
}

# Helper function to create a test package.json
create_package_json() {
    local content="$1"
    local path="${2:-$TEST_DIR/package.json}"
    echo "$content" > "$path"
}

# Helper function to get output value
get_output() {
    local key="$1"
    grep "^${key}=" "$GITHUB_OUTPUT" | cut -d'=' -f2- | tail -1
}

@test "extracts basic package information" {
    create_package_json '{
        "name": "test-package",
        "version": "1.0.0",
        "engines": {
            "node": "18.2.1"
        },
        "packageManager": "npm@8.19.0"
    }'
    
    run extract_package_info "$TEST_DIR" "patch" "package.json"
    
    [ "$status" -eq 0 ]
    [ "$(get_output "package_name")" = "test-package" ]
    [ "$(get_output "package_version")" = "1.0.0" ]
    [ "$(get_output "node_version")" = "18.2.1" ]
    [ "$(get_output "package_manager")" = "npm" ]
    [ "$(get_output "package_manager_version")" = "8.19.0" ]
    [ "$(get_output "lock_file")" = "package-lock.json" ]
    [ "$(get_output "lock_file_path")" = "$TEST_DIR/package-lock.json" ]
}

@test "handles different package managers correctly" {
    # Test PNPM
    create_package_json '{
        "name": "pnpm-test",
        "engines": { "node": "18.0.0" },
        "packageManager": "pnpm@8.15.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "package_manager")" = "pnpm" ]
    [ "$(get_output "lock_file")" = "pnpm-lock.yaml" ]
    [ "$(get_output "lock_file_path")" = "$TEST_DIR/pnpm-lock.yaml" ]
    
    # Test Yarn
    create_package_json '{
        "name": "yarn-test",
        "engines": { "node": "18.0.0" },
        "packageManager": "yarn@3.6.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "package_manager")" = "yarn" ]
    [ "$(get_output "lock_file")" = "yarn.lock" ]
    [ "$(get_output "lock_file_path")" = "$TEST_DIR/yarn.lock" ]
    
    # Test Bun
    create_package_json '{
        "name": "bun-test",
        "engines": { "node": "18.0.0" },
        "packageManager": "bun@1.0.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "package_manager")" = "bun" ]
    [ "$(get_output "lock_file")" = "bun.lockb" ]
    [ "$(get_output "lock_file_path")" = "$TEST_DIR/bun.lockb" ]
}

@test "handles different node version formats" {
    # Test with version prefix
    create_package_json '{
        "engines": { "node": ">=18.0.0" },
        "packageManager": "npm@8.0.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "node_version_full")" = ">=18.0.0" ]
    [ "$(get_output "node_version")" = "18.0.0" ]
    
    # Test with caret prefix
    create_package_json '{
        "engines": { "node": "^16.14.2" },
        "packageManager": "npm@8.0.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "node_version")" = "16.14.2" ]
}

@test "respects node version granularity settings" {
    create_package_json '{
        "engines": { "node": "18.2.1" },
        "packageManager": "npm@8.0.0"
    }'
    
    # Test major granularity
    run extract_package_info "$TEST_DIR" "major"
    [ "$status" -eq 0 ]
    [ "$(get_output "node_version")" = "18" ]
    
    # Test minor granularity
    run extract_package_info "$TEST_DIR" "minor"
    [ "$status" -eq 0 ]
    [ "$(get_output "node_version")" = "18.2" ]
    
    # Test patch granularity (default)
    run extract_package_info "$TEST_DIR" "patch"
    [ "$status" -eq 0 ]
    [ "$(get_output "node_version")" = "18.2.1" ]
}

@test "detects turborepo configuration" {
    create_package_json '{
        "engines": { "node": "18.0.0" },
        "packageManager": "npm@8.0.0"
    }'
    
    # Test without turbo
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "turbo_available")" = "false" ]
    
    # Test with turbo.json
    echo '{}' > "$TEST_DIR/turbo.json"
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "turbo_available")" = "true" ]
    
    # Test with .turbo directory
    rm "$TEST_DIR/turbo.json"
    mkdir "$TEST_DIR/.turbo"
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "turbo_available")" = "true" ]
}

@test "fails when package.json is missing" {
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"package.json not found"* ]]
}

@test "fails when engines.node is missing" {
    create_package_json '{
        "name": "test",
        "packageManager": "npm@8.0.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"engines.node field is required"* ]]
}

@test "fails when packageManager is missing" {
    create_package_json '{
        "name": "test",
        "engines": { "node": "18.0.0" }
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"packageManager field is required"* ]]
}

@test "fails with invalid granularity" {
    create_package_json '{
        "engines": { "node": "18.0.0" },
        "packageManager": "npm@8.0.0"
    }'
    
    run extract_package_info "$TEST_DIR" "invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid node_version_granularity"* ]]
}

@test "handles missing package name and version gracefully" {
    create_package_json '{
        "engines": { "node": "18.0.0" },
        "packageManager": "npm@8.0.0"
    }'
    
    run extract_package_info "$TEST_DIR"
    [ "$status" -eq 0 ]
    [ "$(get_output "package_name")" = "" ]
    [ "$(get_output "package_version")" = "" ]
}

@test "works with custom package.json filename" {
    create_package_json '{
        "engines": { "node": "18.0.0" },
        "packageManager": "npm@8.0.0"
    }' "$TEST_DIR/custom-package.json"
    
    run extract_package_info "$TEST_DIR" "patch" "custom-package.json"
    [ "$status" -eq 0 ]
    [ "$(get_output "package_json_path")" = "$TEST_DIR/custom-package.json" ]
    [ "$(get_output "lock_file_path")" = "$TEST_DIR/package-lock.json" ]
}
