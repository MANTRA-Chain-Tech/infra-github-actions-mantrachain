#!/bin/bash

# Common utilities for Terraform Cloud monitoring scripts

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $*"
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $*" >&2
}

debug_log() {
    if [[ "${DEBUG_LOGGING:-false}" == "true" ]]; then
        echo -e "${BLUE}🐛 DEBUG:${NC} $*"
    fi
}

# Validation functions
validate_required_env() {
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "$var environment variable is required"
            exit 1
        fi
    done
}

# URL encoding function
url_encode() {
    local string="$1"
    echo "$string" | sed 's/ /%20/g'
}

# API request helper
make_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    
    local url="https://app.terraform.io/api/v2/$endpoint"
    debug_log "Making $method request to: $url"
    
    local curl_args=(
        -s
        --request "$method"
        --header "Authorization: Bearer $TF_API_TOKEN"
        --header "Content-Type: application/vnd.api+json"
    )
    
    if [[ -n "$data" ]]; then
        curl_args+=(--data "$data")
    fi
    
    curl_args+=("$url")
    
    local response
    if ! response=$(curl "${curl_args[@]}"); then
        debug_log "curl command failed"
        return 1
    fi
    
    # Check for API errors
    local error_check
    error_check=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -n "$error_check" && "$error_check" != "null" ]]; then
        log_error "API Error: $error_check"
        debug_log "Response: $response"
        return 1
    fi
    
    echo "$response"
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate required commands
validate_commands() {
    local missing_commands=()
    
    for cmd in jq curl; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Please install the missing commands and try again"
        exit 1
    fi
}

# Initialize common setup
init_common() {
    validate_commands
    debug_log "Common utilities initialized"
}

# Call init when sourced
init_common
