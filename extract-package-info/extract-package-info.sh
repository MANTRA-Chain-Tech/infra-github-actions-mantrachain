#!/bin/bash

set -euo pipefail

# Function to extract package information
extract_package_info() {
    local working_directory="${1:-"."}"
    local node_version_granularity="${2:-"patch"}"
    local package_json_filename="${3:-"package.json"}"
    
    # Resolve package.json path
    local package_json_path
    if [[ "$working_directory" == "." ]]; then
        package_json_path="$package_json_filename"
    else
        package_json_path="$working_directory/$package_json_filename"
    fi
    
    # Check if package.json exists
    if [[ ! -f "$package_json_path" ]]; then
        echo "::error::package.json not found at: $package_json_path"
        exit 1
    fi
    
    # Ensure jq is available
    if ! command -v jq &> /dev/null; then
        echo "::error::jq is required but not installed"
        exit 1
    fi
    
    # Extract package name and version
    local package_name
    local package_version
    package_name=$(jq -r '.name // ""' "$package_json_path")
    package_version=$(jq -r '.version // ""' "$package_json_path")
    
    # Extract Node.js version from engines.node
    local node_version_full
    node_version_full=$(jq -r '.engines.node // ""' "$package_json_path")
    if [[ -z "$node_version_full" ]]; then
        echo "::error::engines.node field is required in package.json"
        exit 1
    fi
    
    # Parse Node.js version components
    local node_version_clean
    local node_version_major
    local node_version_minor
    local node_version_patch
    
    # Remove version prefixes and extract clean version
    node_version_clean=$(echo "$node_version_full" | sed -E 's/[^0-9]*([0-9]+(\.[0-9]+)*).*/\1/')
    
    # Split version into components
    IFS='.' read -ra VERSION_PARTS <<< "$node_version_clean"
    node_version_major="${VERSION_PARTS[0]:-}"
    node_version_minor="${VERSION_PARTS[1]:-0}"
    node_version_patch="${VERSION_PARTS[2]:-0}"
    
    # Format version according to granularity
    local node_version
    case "$node_version_granularity" in
        major)
            node_version="$node_version_major"
            ;;
        minor)
            node_version="$node_version_major.$node_version_minor"
            ;;
        patch)
            node_version="$node_version_major.$node_version_minor.$node_version_patch"
            ;;
        *)
            echo "::error::Invalid node_version_granularity: $node_version_granularity. Must be 'major', 'minor', or 'patch'"
            exit 1
            ;;
    esac
    
    # Extract package manager from packageManager field
    local package_manager_full
    package_manager_full=$(jq -r '.packageManager // ""' "$package_json_path")
    if [[ -z "$package_manager_full" ]]; then
        echo "::error::packageManager field is required in package.json (e.g., 'npm@8.19.0', 'pnpm@8.15.0', or 'yarn@3.6.0')"
        exit 1
    fi
    
    # Parse package manager type and version
    local package_manager
    local package_manager_version
    if [[ "$package_manager_full" == *"@"* ]]; then
        package_manager=$(echo "$package_manager_full" | cut -d'@' -f1)
        package_manager_version=$(echo "$package_manager_full" | cut -d'@' -f2)
    else
        echo "::error::Invalid packageManager format in package.json. Expected format: <name>@<version> (e.g., 'npm@8.19.0')"
        echo "Found: $package_manager_full"
        exit 1
    fi
    
    if [[ -z "$package_manager" ]] || [[ -z "$package_manager_version" ]]; then
        echo "::error::Invalid packageManager format in package.json"
        echo "Expected format: <name>@<version> (e.g., 'npm@8.19.0')"
        echo "Found: $package_manager_full"
        exit 1
    fi
    
    # Determine lock file based on package manager
    local lock_file
    case "$package_manager" in
        npm)
            lock_file="package-lock.json"
            ;;
        pnpm)
            lock_file="pnpm-lock.yaml"
            ;;
        yarn)
            lock_file="yarn.lock"
            ;;
        bun)
            lock_file="bun.lockb"
            ;;
        *)
            echo "::warning::Unknown package manager: $package_manager. Lock file detection may be inaccurate."
            lock_file="${package_manager}.lock"
            ;;
    esac
    
    # Calculate lock file path
    local lock_file_path
    if [[ "$working_directory" == "." ]]; then
        lock_file_path="$lock_file"
    else
        lock_file_path="$working_directory/$lock_file"
    fi

    # Check for Turborepo configuration
    local turbo_available="false"
    local turbo_config_dir
    if [[ "$working_directory" == "." ]]; then
        turbo_config_dir="."
    else
        turbo_config_dir="$working_directory"
    fi
    
    if [[ -d "$turbo_config_dir/.turbo" ]] || [[ -f "$turbo_config_dir/turbo.json" ]]; then
        turbo_available="true"
        echo "Turborepo configuration found"
    else
        echo "No Turborepo configuration found"
    fi
    
    # Output all extracted information
    echo "node_version=$node_version" >> "$GITHUB_OUTPUT"
    echo "node_version_full=$node_version_full" >> "$GITHUB_OUTPUT"
    echo "package_manager=$package_manager" >> "$GITHUB_OUTPUT"
    echo "package_manager_version=$package_manager_version" >> "$GITHUB_OUTPUT"
    echo "package_manager_full=$package_manager_full" >> "$GITHUB_OUTPUT"
    echo "lock_file=$lock_file" >> "$GITHUB_OUTPUT"
    echo "lock_file_path=$lock_file_path" >> "$GITHUB_OUTPUT"
    echo "package_name=$package_name" >> "$GITHUB_OUTPUT"
    echo "package_version=$package_version" >> "$GITHUB_OUTPUT"
    echo "turbo_available=$turbo_available" >> "$GITHUB_OUTPUT"
    echo "package_json_path=$package_json_path" >> "$GITHUB_OUTPUT"
    
    # Log extracted information
    echo "📦 Package Information Extracted:"
    echo "  📄 Package: $package_name@$package_version"
    echo "  🟢 Node.js: $node_version_full (using: $node_version)"
    echo "  📦 Package Manager: $package_manager@$package_manager_version"
    echo "  🔒 Lock File: $lock_file"
    echo "  📍 Lock File Path: $lock_file_path"
    echo "  ⚡ Turborepo: $turbo_available"
    echo "  📍 Path: $package_json_path"
}

# If script is run directly, execute the function with provided arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    extract_package_info "$@"
fi
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    extract_package_info "$@"
fi
