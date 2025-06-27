#!/bin/bash

set -euo pipefail

# Default policies if none provided - using MantraChain policies
DEFAULT_POLICIES="1a3e0a22-040d-4941-a899-a370548e5bd5:1,66f03940-062b-4d65-9c32-7c714ac89194:2"

# Function to check if app exists and return app ID
check_app_exists() {
    local domain="$1"
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/access/apps" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    local app_id
    app_id=$(echo "$response" | jq -r ".result[]? | select(.domain == \"$domain\") | .id")
    if [ "$app_id" = "null" ] || [ -z "$app_id" ]; then
        echo ""
    else
        echo "$app_id"
    fi
}

# Function to delete app if it exists
delete_app() {
    local domain="$1"
    local app_id
    app_id=$(check_app_exists "$domain")
    
    if [ -n "$app_id" ] && [ "$app_id" != "null" ]; then
        echo "Deleting existing application with ID: $app_id"
        local response
        response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/access/apps/$app_id" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json")
        
        local success
        success=$(echo "$response" | jq -r '.success')
        if [ "$success" != "true" ]; then
            echo "Error deleting application: $(echo "$response" | jq -r '.errors')"
            exit 1
        fi
        echo "Application deleted successfully"
        
        # Wait for deletion to propagate
        echo "Waiting for deletion to propagate..."
        local attempts=0
        while [ $attempts -lt 10 ]; do
            sleep 2
            local check_result
            check_result=$(check_app_exists "$domain")
            if [ -z "$check_result" ]; then
                echo "Deletion confirmed"
                break
            fi
            attempts=$((attempts + 1))
            echo "Still waiting for deletion to propagate (attempt $attempts/10)..."
        done
    else
        echo "No application found with domain $domain"
    fi
}

# Function to parse policies string into JSON array
parse_policies() {
    local policies_str="$1"
    local policies_json="["
    local first=true
    
    IFS=',' read -ra POLICIES <<< "$policies_str"
    for policy in "${POLICIES[@]}"; do
        IFS=':' read -ra POLICY_PARTS <<< "$policy"
        local policy_id="${POLICY_PARTS[0]}"
        local precedence="${POLICY_PARTS[1]}"
        
        if [ "$first" = true ]; then
            first=false
        else
            policies_json+=","
        fi
        policies_json+="{\"id\":\"$policy_id\",\"precedence\":$precedence}"
    done
    policies_json+="]"
    echo "$policies_json"
}

# Function to create app
create_app() {
    local name="$1"
    local domain="$2"
    local policies_str="$3"
    
    # If policies string is empty, use default
    if [ -z "$policies_str" ]; then
        policies_str="$DEFAULT_POLICIES"
    fi
    
    # Check if app already exists and delete it first
    local existing_app_id
    existing_app_id=$(check_app_exists "$domain")
    if [ -n "$existing_app_id" ]; then
        echo "Application already exists with domain $domain, deleting first..."
        delete_app "$domain"
    fi
    
    local policies_json
    policies_json=$(parse_policies "$policies_str")
    
    # Validate JSON is properly formed
    if ! echo "$policies_json" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid policies JSON generated: $policies_json" >&2
        exit 1
    fi
    
    echo "Creating Cloudflare Access App: $name..." >&2
    
    local payload
    payload=$(cat <<EOF
{
    "name": "$name",
    "domain": "$domain",
    "type": "self_hosted",
    "policies": $policies_json,
    "allowed_idps": [],
    "auto_redirect_to_identity": false,
    "session_duration": "24h",
    "http_only_cookie_attribute": true,
    "enable_binding_cookie": false,
    "app_launcher_visible": true,
    "service_auth_401_redirect": false,
    "options": {
        "warp_auth_identity_required": true
    }
}
EOF
)
    
    # Validate payload JSON
    if ! echo "$payload" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid JSON payload generated" >&2
        exit 1
    fi
    
    local response
    response=$(curl -s -w "HTTP_CODE:%{http_code}\n" -X POST "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/access/apps" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    # Extract HTTP code and response body
    local http_code
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local response_body
    response_body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    # Handle 409 conflict specifically
    if [ "$http_code" = "409" ]; then
        echo "Conflict detected (HTTP 409) - app may still exist, retrying deletion..." >&2
        delete_app "$domain"
        # Retry creation
        response=$(curl -s -w "HTTP_CODE:%{http_code}\n" -X POST "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/access/apps" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$payload" 2>&1)
        http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
        response_body=$(echo "$response" | grep -v "HTTP_CODE:")
    fi
    
    if [ -z "$response_body" ] || ! echo "$response_body" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid or empty JSON response (HTTP $http_code)" >&2
        echo "Response: $response_body" >&2
        exit 1
    fi
    
    local success
    success=$(echo "$response_body" | jq -r '.success // false')
    
    if [ "$success" != "true" ]; then
        echo "Error creating application (HTTP $http_code):" >&2
        echo "$response_body" | jq -r '.errors // "Unknown error"' >&2
        exit 1
    fi
    
    local app_id
    app_id=$(echo "$response_body" | jq -r '.result.id')
    echo "Application created successfully with ID: $app_id" >&2
    
    # Wait for creation to propagate
    echo "Waiting for creation to propagate..." >&2
    local attempts=0
    while [ $attempts -lt 10 ]; do
        sleep 2
        local check_result
        check_result=$(check_app_exists "$domain")
        if [ "$check_result" = "$app_id" ]; then
            echo "Creation confirmed" >&2
            break
        fi
        attempts=$((attempts + 1))
        echo "Still waiting for creation to propagate (attempt $attempts/10)..." >&2
    done
    
    echo "$app_id"
}

# Main function
main() {
    local action=""
    local name=""
    local domain=""
    local policies="$DEFAULT_POLICIES"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --action)
                action="$2"
                shift 2
                ;;
            --name)
                name="$2"
                shift 2
                ;;
            --domain)
                domain="$2"
                shift 2
                ;;
            --policies)
                policies="$2"
                shift 2
                ;;
            *)
                echo "Unknown option $1"
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$action" ] || [ -z "$name" ] || [ -z "$domain" ]; then
        echo "Usage: $0 --action <create|delete> --name <app_name> --domain <domain> [--policies <policies>]"
        echo "Policies format: POLICY_ID1:PRECEDENCE1,POLICY_ID2:PRECEDENCE2"
        exit 1
    fi
    
    # Validate environment variables
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
        echo "Error: CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN environment variables must be set"
        exit 1
    fi
    
    case "$action" in
        create)
            # Create app (with built-in idempotent behavior)
            echo "Creating application..."
            local app_id
            app_id=$(create_app "$name" "$domain" "$policies")
            echo "App ID: $app_id"
            echo "::set-output name=app_id::$app_id"
            ;;
        delete)
            delete_app "$domain"
            echo "::set-output name=app_id::"
            ;;
        *)
            echo "Invalid action: $action. Must be 'create' or 'delete'"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi