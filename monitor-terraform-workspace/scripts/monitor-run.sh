#!/bin/bash
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Input validation
validate_required_env "TF_API_TOKEN" "WORKSPACE_ID"

# Configuration
WORKSPACE_NAME="${WORKSPACE_NAME:-}"
ORGANIZATION="${ORGANIZATION:-}"
MONITOR_PURPOSE="${MONITOR_PURPOSE:-workspace}"
TIMEOUT_MINUTES="${TIMEOUT_MINUTES:-10}"
POLLING_INTERVAL_SECONDS="${POLLING_INTERVAL_SECONDS:-5}"
INITIAL_WAIT_SECONDS="${INITIAL_WAIT_SECONDS:-10}"
DEBUG_LOGGING="${DEBUG_LOGGING:-false}"

# Function to generate summary markdown
generate_summary_markdown() {
    local run_id="$1"
    local run_url="$2"
    local run_status="$3"
    
    local summary=""
    if [[ -n "$run_id" ]]; then
        summary+="- **Run ID**: \`$run_id\`\n"
    fi
    if [[ -n "$run_url" ]]; then
        summary+="- **Run URL**: [$run_url]($run_url)\n"
    fi
    if [[ -n "$run_status" ]]; then
        summary+="- **Final Status**: \`$run_status\`\n"
    fi
    summary+="- **Monitor Purpose**: $MONITOR_PURPOSE\n"
    
    echo "$summary"
}

# Function to check run status and determine if it's final
is_final_status() {
    local status="$1"
    case "$status" in
        "applied"|"planned_and_finished"|"errored"|"canceled"|"force_canceled"|"discarded")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if status is successful
is_success_status() {
    local status="$1"
    case "$status" in
        "applied"|"planned_and_finished")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Main monitoring function
monitor_terraform_run() {
    log_info "Starting to monitor $MONITOR_PURPOSE runs..."
    log_info "Workspace: $WORKSPACE_NAME (ID: $WORKSPACE_ID)"
    
    debug_log "Monitoring configuration:"
    debug_log "- Organization: $ORGANIZATION"
    debug_log "- Workspace: $WORKSPACE_NAME"
    debug_log "- Workspace ID: $WORKSPACE_ID"
    debug_log "- Purpose: $MONITOR_PURPOSE"
    debug_log "- Timeout: $TIMEOUT_MINUTES minutes"
    debug_log "- Polling interval: $POLLING_INTERVAL_SECONDS seconds"
    debug_log "- Initial wait: $INITIAL_WAIT_SECONDS seconds"
    
    # Calculate timeout timestamp
    local timeout_seconds=$((TIMEOUT_MINUTES * 60))
    local end_time=$(($(date +%s) + timeout_seconds))
    
    debug_log "Current time: $(date)"
    debug_log "Timeout timestamp: $end_time"
    debug_log "Will timeout at: $(date -d @$end_time 2>/dev/null || date -r $end_time 2>/dev/null || echo "N/A")"
    
    # Wait for run to be triggered
    log_info "Waiting $INITIAL_WAIT_SECONDS seconds for Terraform run to be triggered..."
    sleep "$INITIAL_WAIT_SECONDS"
    
    local run_found="false"
    local run_status=""
    local run_url=""
    local run_id=""
    local iteration_count=0
    local last_checked_run_id=""
    
    while [[ $(date +%s) -lt $end_time ]]; do
        iteration_count=$((iteration_count + 1))
        local current_time
        current_time=$(date +%s)
        local remaining_time
        remaining_time=$((end_time - current_time))
        
        debug_log "=== Iteration #$iteration_count ==="
        debug_log "Current time: $(date)"
        debug_log "Remaining time: ${remaining_time}s"
        
        log_info "Polling Terraform Cloud for workspace runs..."
        
        local runs_response
        if ! runs_response=$(make_api_request "GET" "workspaces/$WORKSPACE_ID/runs?page%5Bsize%5D=10"); then
            log_warn "Failed to fetch runs, retrying..."
            sleep "$POLLING_INTERVAL_SECONDS"
            continue
        fi
        
        debug_log "API Response length: ${#runs_response} characters"
        
        # Extract latest run information
        local latest_run
        latest_run=$(echo "$runs_response" | jq -r '.data[0] // empty')
        debug_log "Latest run data: $latest_run"
        
        local run_count
        run_count=$(echo "$runs_response" | jq -r '.data | length')
        debug_log "Total runs found: $run_count"
        
        if [[ -n "$latest_run" && "$latest_run" != "null" ]]; then
            run_id=$(echo "$latest_run" | jq -r '.id')
            run_status=$(echo "$latest_run" | jq -r '.attributes.status')
            local run_created_at
            run_created_at=$(echo "$latest_run" | jq -r '.attributes."created-at"')
            local run_source
            run_source=$(echo "$latest_run" | jq -r '.attributes.source // "unknown"')
            run_url="https://app.terraform.io/app/$ORGANIZATION/workspaces/$WORKSPACE_NAME/runs/$run_id"
            
            # Only log if this is a new run
            if [[ "$run_id" != "$last_checked_run_id" ]]; then
                log_info "Found run: $run_id with status: $run_status"
                log_info "Run URL: $run_url"
                log_info "Run source: $run_source"
                last_checked_run_id="$run_id"
            fi
            
            debug_log "Run created at: $run_created_at"
            debug_log "Run ID: $run_id"
            debug_log "Run status: $run_status"
            debug_log "Run source: $run_source"
            
            run_found="true"
            
            # Check if run is in final state
            if is_final_status "$run_status"; then
                if is_success_status "$run_status"; then
                    log_success "Terraform run completed successfully!"
                    echo "RUN_STATUS=success"
                    echo "RUN_URL=$run_url"
                    echo "RUN_ID=$run_id"
                    
                    local summary_md
                    summary_md=$(generate_summary_markdown "$run_id" "$run_url" "$run_status")
                    echo "SUMMARY_MARKDOWN<<EOF"
                    echo -e "$summary_md"
                    echo "EOF"
                    
                    # The script should output run_status to GITHUB_OUTPUT
                    echo "run_status=success" >> "$GITHUB_OUTPUT"
                    
                    return 0
                else
                    log_error "Terraform run failed with status: $run_status"
                    echo "RUN_STATUS=failed"
                    echo "RUN_URL=$run_url"
                    echo "RUN_ID=$run_id"
                    echo "ERROR_MESSAGE=Terraform run failed with status: $run_status"
                    
                    local summary_md
                    summary_md=$(generate_summary_markdown "$run_id" "$run_url" "$run_status")
                    echo "SUMMARY_MARKDOWN<<EOF"
                    echo -e "$summary_md"
                    echo "EOF"
                    
                    # The script should output run_status to GITHUB_OUTPUT
                    echo "run_status=failed" >> "$GITHUB_OUTPUT"
                    
                    return 1
                fi
            else
                log_info "⏳ Terraform run in progress with status: $run_status"
                debug_log "Run is in progress, continuing to monitor..."
            fi
        else
            log_info "No runs found yet, waiting for Terraform to trigger..."
            debug_log "No runs returned from API"
        fi
        
        log_info "Waiting $POLLING_INTERVAL_SECONDS seconds before next check..."
        debug_log "Sleeping for $POLLING_INTERVAL_SECONDS seconds..."
        sleep "$POLLING_INTERVAL_SECONDS"
    done
    
    # Timeout reached
    debug_log "Timeout reached after $iteration_count iterations"
    debug_log "Final status - RUN_FOUND: $run_found, RUN_STATUS: $run_status"
    
    if [[ "$run_found" == "true" ]]; then
        log_warn "Timeout reached while waiting for Terraform run to complete"
        log_warn "Last known status: $run_status"
        echo "RUN_STATUS=timeout"
        echo "RUN_URL=$run_url"
        echo "RUN_ID=$run_id"
        echo "ERROR_MESSAGE=Timeout reached while waiting for run to complete. Last status: $run_status"
    else
        log_warn "Timeout reached - no Terraform run was found"
        echo "RUN_STATUS=no-run-found"
        echo "ERROR_MESSAGE=No Terraform run found within $TIMEOUT_MINUTES minutes"
    fi
    
    # Generate summary markdown for timeout/no-run-found cases
    local summary_md
    summary_md=$(generate_summary_markdown "$run_id" "$run_url" "$run_status")
    echo "SUMMARY_MARKDOWN<<EOF"
    echo -e "$summary_md"
    echo "EOF"
    
    return 1
}

# Run the monitoring function
monitor_terraform_run "$@"
