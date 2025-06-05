#!/bin/bash
set -euo pipefail

# Test runner script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Running Terraform Cloud Monitor Tests"
echo "========================================"
echo

# Check if we're in the right directory
if [[ ! -d "$SCRIPT_DIR/../scripts" ]]; then
    echo "❌ Error: Scripts directory not found. Are you running from the correct location?"
    exit 1
fi

# Check dependencies
echo "🔍 Checking dependencies..."
for cmd in jq curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ Error: $cmd is required but not installed"
        exit 1
    else
        echo "✅ $cmd is available"
    fi
done
echo

# Run individual test files
TEST_FILES=(
    "test-resolve-workspace.sh"
    "test-monitor-run.sh"
    # Add more test files as they are created
)

TOTAL_FAILURES=0

for test_file in "${TEST_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$test_file" ]]; then
        echo "🏃 Running $test_file..."
        echo "----------------------------------------"
        
        if "$SCRIPT_DIR/$test_file"; then
            echo "✅ $test_file completed successfully"
        else
            echo "❌ $test_file failed"
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        fi
        echo
    else
        echo "⚠️  Test file $test_file not found, skipping..."
        echo
    fi
done

# Final summary
echo "========================================"
if [[ $TOTAL_FAILURES -eq 0 ]]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "💥 $TOTAL_FAILURES test file(s) failed"
    exit 1
fi
