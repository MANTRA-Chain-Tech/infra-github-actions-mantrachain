#!/bin/bash
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

# Input validation
validate_required_env "TF_API_TOKEN" "ORGANIZATION"

# Configuration
INPUT_WORKSPACE_NAME="${INPUT_WORKSPACE_NAME:-}"
INPUT_WORKSPACE_ID="${INPUT_WORKSPACE_ID:-}"
DEBUG_LOGGING="${DEBUG_LOGGING:-false}"

# Function to resolve workspace by ID
resolve_by_id() {
    local workspace_id="$1"
    
    log_info "Using provided workspace ID: $workspace_id"
    
    # Get workspace name from ID
    debug_log "Fetching workspace details for ID: $workspace_id"
    
    local workspace_response
    if ! workspace_response=$(make_api_request "GET" "workspaces/$workspace_id"); then
        log_error "Failed to fetch workspace details"
        return 1
    fi
    
    local workspace_name
    workspace_name=$(echo "$workspace_response" | jq -r '.data.attributes.name // empty')
    if [[ -z "$workspace_name" || "$workspace_name" == "null" ]]; then
        log_error "Could not retrieve workspace name for ID: $workspace_id"
        debug_log "Workspace response: $workspace_response"
        return 1
    fi
    
    log_info "Resolved workspace name: $workspace_name"
    
    # Output results
    echo "WORKSPACE_ID=$workspace_id"
    echo "WORKSPACE_NAME=$workspace_name"
    
    return 0
}

# Function to resolve workspace by name
resolve_by_name() {
    local workspace_name="$1"
    
    log_info "Resolving workspace ID for name: $workspace_name"
    debug_log "Fetching workspace ID for name: $workspace_name"
    
    # URL encode the workspace name
    local encoded_workspace_name
    encoded_workspace_name=$(url_encode "$workspace_name")
    
    local workspace_response
    if ! workspace_response=$(make_api_request "GET" "organizations/$ORGANIZATION/workspaces/$encoded_workspace_name"); then
        log_error "Failed to fetch workspace by name"
        return 1
    fi
    
    local workspace_id
    workspace_id=$(echo "$workspace_response" | jq -r '.data.id // empty')
    if [[ -z "$workspace_id" || "$workspace_id" == "null" ]]; then
        log_error "Could not find workspace: $workspace_name"
        debug_log "Workspace response: $workspace_response"
        return 1
    fi
    
    log_info "Resolved workspace ID: $workspace_id"
    
    # Output results
    echo "WORKSPACE_ID=$workspace_id"
    echo "WORKSPACE_NAME=$workspace_name"
    
    return 0
}

# Main resolution logic
main() {
    debug_log "Starting workspace resolution"
    debug_log "INPUT_WORKSPACE_ID: ${INPUT_WORKSPACE_ID:-<empty>}"
    debug_log "INPUT_WORKSPACE_NAME: ${INPUT_WORKSPACE_NAME:-<empty>}"
    debug_log "ORGANIZATION: $ORGANIZATION"
    
    if [[ -n "$INPUT_WORKSPACE_ID" ]]; then
        if ! resolve_by_id "$INPUT_WORKSPACE_ID"; then
            return 1
        fi
    elif [[ -n "$INPUT_WORKSPACE_NAME" ]]; then
        if ! resolve_by_name "$INPUT_WORKSPACE_NAME"; then
            return 1
        fi
    else
        log_error "Neither workspace_id nor workspace_name is provided"
        return 1
    fi
    
    debug_log "Workspace resolution completed successfully"
    
    return 0
}

# Run the main function
main "$@"
