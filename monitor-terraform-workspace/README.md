# Monitor Terraform Cloud Workspace Action

This GitHub action monitors Terraform Cloud workspace runs and waits for their completion. It supports monitoring both by workspace ID and workspace name, with comprehensive logging and error handling.

## 📁 Project Structure

```
monitor-terraform-workspace/
├── action.yaml                    # GitHub Action definition
├── README.md                      # This file
├── scripts/                       # Core shell scripts
│   ├── common.sh                  # Shared utilities and functions
│   ├── monitor-workspace.sh       # Main orchestration script
│   ├── resolve-workspace.sh       # Workspace ID/name resolution
│   └── monitor-run.sh             # Run monitoring logic
└── tests/                         # Test scripts for local development
    ├── run-tests.sh               # Test runner
    ├── test-common.sh             # Test utilities
    └── test-resolve-workspace.sh  # Tests for workspace resolution
```

## 🚀 Features

- **Flexible Workspace Identification**: Use either workspace ID or workspace name
- **Comprehensive Monitoring**: Tracks run status from start to completion
- **Detailed Logging**: Optional debug logging for troubleshooting
- **Error Handling**: Provides detailed error information and failure reasons
- **Status Reporting**: Returns detailed status information for downstream actions
- **Modular Design**: Separated scripts for maintainability
- **Test Coverage**: Unit tests for local development and validation

## 📋 Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `terraform_token` | Terraform Cloud API token | Yes | - |
| `organization` | Terraform Cloud organization name | Yes | - |
| `workspace_name` | Terraform Cloud workspace name (use this OR workspace_id) | No | - |
| `workspace_id` | Terraform Cloud workspace ID (use this OR workspace_name) | No | - |
| `timeout_minutes` | Timeout in minutes for monitoring | No | `10` |
| `polling_interval_seconds` | Polling interval in seconds | No | `5` |
| `initial_wait_seconds` | Initial wait time in seconds before polling | No | `10` |
| `debug_logging` | Enable debug logging | No | `false` |
| `monitor_purpose` | Purpose description for logging | No | `workspace` |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `run_status` | Final status of the Terraform run (`success`, `failed`, `timeout`, `no-run-found`) |
| `run_url` | URL to the Terraform run in Terraform Cloud |
| `run_id` | ID of the Terraform run |
| `workspace_id` | ID of the workspace that was monitored |
| `workspace_name` | Name of the workspace that was monitored |
| `error_message` | Error message if monitoring failed |
| `summary_markdown` | Markdown summary of the monitoring results |

## 📖 Usage Examples

### Monitor by Workspace ID

```yaml
- name: Monitor Terraform Run
  uses: ./.github/actions/monitor-terraform-workspace
  with:
    terraform_token: ${{ secrets.TERRAFORM_CLOUD_TOKEN }}
    organization: 'my-organization'
    workspace_id: 'ws-ABC123'
    timeout_minutes: '10'
    debug_logging: true
    monitor_purpose: 'main workspace'
```

### Monitor by Workspace Name

```yaml
- name: Monitor Terraform Run
  uses: ./.github/actions/monitor-terraform-workspace
  with:
    terraform_token: ${{ secrets.TERRAFORM_CLOUD_TOKEN }}
    organization: 'my-organization'
    workspace_name: 'my-workspace'
    timeout_minutes: '10'
    polling_interval_seconds: '60'
    debug_logging: false
```

### Sequential Monitoring (Parent then Child)

```yaml
- name: Monitor Parent Workspace
  id: monitor-parent
  uses: ./.github/actions/monitor-terraform-workspace
  with:
    terraform_token: ${{ secrets.TERRAFORM_CLOUD_TOKEN }}
    organization: 'my-organization'
    workspace_id: 'ws-PARENT123'
    monitor_purpose: 'parent workspace'

- name: Monitor Child Workspace
  id: monitor-child
  if: steps.monitor-parent.outputs.run_status == 'success'
  uses: ./.github/actions/monitor-terraform-workspace
  with:
    terraform_token: ${{ secrets.TERRAFORM_CLOUD_TOKEN }}
    organization: 'my-organization'
    workspace_name: 'child-workspace'
    timeout_minutes: '15'
    monitor_purpose: 'child workspace'
```

## 🔍 Run Status Values

- **`success`**: Terraform run completed successfully (status: `applied` or `planned_and_finished`)
- **`failed`**: Terraform run failed (status: `errored`, `canceled`, `force_canceled`, or `discarded`)
- **`timeout`**: Monitoring timed out while run was still in progress
- **`no-run-found`**: No Terraform run was found within the timeout period

## 🐛 Debug Logging

When `debug_logging` is set to `true`, the action will output detailed information including:

- API requests and responses
- Workspace resolution details
- Run status changes
- Timing information
- Error details

This is useful for troubleshooting but may produce verbose output in production workflows.

## 🧪 Local Development and Testing

### Running Tests

To run the test suite locally:

```bash
cd .github/actions/monitor-terraform-workspace/tests
./run-tests.sh
```

### Test Types

The action includes two types of tests:

1. **Unit Tests** (`test-resolve-workspace.sh`): Test workspace resolution logic with mocked API responses
2. **Integration Tests** (`test-monitor-run.sh`): Test complete run monitoring against real Terraform Cloud workspace

### Testing Individual Scripts

You can test individual scripts directly:

```bash
# Test workspace resolution
export TF_API_TOKEN="your-token"
export ORGANIZATION="your-org"
export INPUT_WORKSPACE_NAME="your-workspace"
./scripts/resolve-workspace.sh

# Test with debug logging
export DEBUG_LOGGING="true"
./scripts/resolve-workspace.sh
```

### Running Individual Test Suites

```bash
# Run only workspace resolution tests (unit tests)
./test-resolve-workspace.sh

# Run only run monitoring tests (integration tests)
./test-monitor-run.sh

# Run with debug output
./test-monitor-run.sh --debug
```

### Troubleshooting Tests

If tests are failing:

1. **Check script exists**: Ensure `scripts/resolve-workspace.sh` exists and is executable
2. **Run with debug**: Set `DEBUG_LOGGING=true` before running tests
3. **Check individual test output**: Run specific test files directly
4. **Verify mock responses**: Check that test-common.sh mock_curl responses match expected format

```bash
# Debug a specific test
DEBUG_LOGGING=true ./test-resolve-workspace.sh

# Check if script exists
ls -la ../scripts/resolve-workspace.sh

# Test mock curl directly
export MOCK_CURL=true
source test-common.sh
setup_test_env
mock_curl -H "Authorization: Bearer test" "https://app.terraform.io/api/v2/workspaces/ws-test123"
```

### Understanding Test Numbers

Tests are numbered sequentially as they run. Each `assert_*` function call increments the test counter:

**Unit Tests (test-resolve-workspace.sh):**
- **Test 1-2**: Input validation tests (missing env vars, missing workspace inputs)
- **Test 3-4**: Workspace resolution by ID tests (workspace ID output, workspace name output)  
- **Test 5-6**: Workspace resolution by name tests (workspace ID output, workspace name output)

**Integration Tests (test-monitor-run.sh):**
- **Test 1**: Monitor run by workspace ID (validates complete workflow including workspace_id and workspace_name outputs)
- **Test 2**: Monitor run by workspace name (validates name resolution + monitoring)
- **Test 3**: Timeout behavior testing (validates timeout handling)
- **Test 4**: Debug logging verification (validates debug output)
- **Test 5**: Monitor purpose output (validates custom purpose messaging)

### Adding New Tests

1. Create a new test file in the `tests/` directory
2. Follow the pattern in `test-resolve-workspace.sh`
3. Add the test file to the `TEST_FILES` array in `run-tests.sh`
4. Use descriptive test messages in `assert_*` functions for better debugging

## Development

### Testing

The action includes comprehensive test suites for all components. Tests are located in the `tests/` directory.

#### Test Infrastructure

Tests use a real Terraform Cloud workspace to ensure accurate validation:
- **Organization**: `mantrachain`
- **Workspace**: `dapps-workspaces-manager`
- **Workspace ID**: `ws-XrQGnGJySWE6Ac3R`

This workspace is specifically maintained for testing purposes and provides:
- Idempotent test execution (tests can be run multiple times safely)
- Real API validation without mocks
- Consistent test results
- Integration testing of complete monitoring workflows

#### Running Tests

To run the tests, you must provide a valid Terraform Cloud API token:

```bash
# Export your Terraform Cloud API token
export TF_API_TOKEN="your-terraform-cloud-api-token"

# Run all tests (unit + integration)
./tests/run-tests.sh

# Run with debug output
./tests/run-tests.sh --debug

# Run individual test suites
./tests/test-resolve-workspace.sh    # Unit tests only
./tests/test-monitor-run.sh          # Integration tests only
```

**Note**: The token must have read access to the `mantrachain/dapps-workspaces-manager` workspace.

#### Integration Test Scenarios

The integration tests cover realistic monitoring scenarios:

1. **Active Run Monitoring**: If the workspace has an active run, tests validate proper status tracking
2. **No Active Run**: Tests validate `no-run-found` status when no runs are active  
3. **Timeout Handling**: Tests validate proper timeout behavior with very short timeouts
4. **Debug Output**: Tests validate that debug logging produces expected output
5. **Purpose Tracking**: Tests validate that custom monitor purposes appear in outputs
