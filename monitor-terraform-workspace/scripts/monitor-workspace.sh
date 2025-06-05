#!/bin/bash
set -euo pipefail

# Main script that orchestrates workspace resolution and monitoring

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Validate required environment variables
validate_required_env "TF_API_TOKEN" "ORGANIZATION"

# Configuration
INPUT_WORKSPACE_NAME="${INPUT_WORKSPACE_NAME:-}"
INPUT_WORKSPACE_ID="${INPUT_WORKSPACE_ID:-}"
DEBUG_LOGGING="${DEBUG_LOGGING:-false}"

# Set GITHUB_OUTPUT to /dev/null if not defined (for local testing)
export GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"

main() {
    log_info "Starting Terraform Cloud workspace monitoring"
    
    # Step 1: Resolve workspace
    log_info "Step 1: Resolving workspace..."
    
    # Initialize variables
    local workspace_id=""
    local workspace_name=""
    
    # Temporarily disable exit on error to capture output
    set +e
    local workspace_output
    workspace_output=$("$SCRIPT_DIR/resolve-workspace.sh" 2>&1)
    local resolve_exit_code=$?
    set -e
    
    if [[ $resolve_exit_code -ne 0 ]]; then
        log_error "Failed to resolve workspace"
        debug_log "Resolve output: $workspace_output"
        return 1
    fi
    
    # Parse workspace resolution output
    workspace_id=$(echo "$workspace_output" | grep "^WORKSPACE_ID=" | cut -d'=' -f2 || echo "")
    workspace_name=$(echo "$workspace_output" | grep "^WORKSPACE_NAME=" | cut -d'=' -f2 || echo "")
    
    if [[ -z "$workspace_id" || -z "$workspace_name" ]]; then
        log_error "Failed to parse workspace resolution output"
        debug_log "Workspace output: $workspace_output"
        return 1
    fi
    
    log_success "Workspace resolved: $workspace_name (ID: $workspace_id)"
    
    # Export for monitor script
    export WORKSPACE_ID="$workspace_id"
    export WORKSPACE_NAME="$workspace_name"
    
    # Step 2: Monitor runs
    log_info "Step 2: Monitoring workspace runs..."
    
    if ! "$SCRIPT_DIR/monitor-run.sh"; then
        log_error "Monitoring failed"
        return 1
    fi
    
    # Output workspace information to GitHub Actions (only if GITHUB_OUTPUT is set)
    if [[ -n "${GITHUB_OUTPUT:-}" && "$GITHUB_OUTPUT" != "/dev/null" ]]; then
        echo "WORKSPACE_ID=$workspace_id" >> "$GITHUB_OUTPUT"
        echo "WORKSPACE_NAME=$workspace_name" >> "$GITHUB_OUTPUT"
    fi
    
    log_success "Monitoring completed successfully"
    return 0
}

# Run main function
main "$@"
