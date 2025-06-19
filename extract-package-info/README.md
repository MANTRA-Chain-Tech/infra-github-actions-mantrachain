# Extract Package Info Action

A comprehensive GitHub Action that extracts Node.js and package manager information from `package.json` files.

## Features

- ✅ **Universal Package Manager Support**: npm, pnpm, yarn, bun, and others
- ✅ **Flexible Node.js Versioning**: Configure granularity (major, minor, patch)
- ✅ **Comprehensive Information**: Extract name, version, lock files, Turborepo detection
- ✅ **Testable**: Core logic implemented in bash with BATS tests
- ✅ **Error Handling**: Clear error messages for missing or invalid configurations

## Usage

```yaml
- name: Extract Package Information
  id: package-info
  uses: your-org/infra-github-actions-mantrachain/extract-package-info@main
  with:
    working_directory: './frontend'
    node_version_granularity: 'major'
    package_json_path: 'package.json'

- name: Use extracted information
  run: |
    echo "Node.js version: ${{ steps.package-info.outputs.node_version }}"
    echo "Package manager: ${{ steps.package-info.outputs.package_manager }}"
    echo "Lock file: ${{ steps.package-info.outputs.lock_file }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `working_directory` | Working directory containing package.json | No | `.` |
| `node_version_granularity` | Node.js version granularity: major, minor, or patch | No | `patch` |
| `package_json_path` | Custom path to package.json file | No | `package.json` |

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `node_version` | Node.js version (formatted according to granularity) | `18.2.1` (patch), `18.2` (minor), `18` (major) |
| `node_version_full` | Full Node.js version string from package.json | `>=18.0.0` |
| `package_manager` | Package manager name | `pnpm` |
| `package_manager_version` | Package manager version | `8.15.0` |
| `package_manager_full` | Full package manager string | `pnpm@8.15.0` |
| `lock_file` | Corresponding lock file name | `pnpm-lock.yaml` |
| `lock_file_path` | Full path to the lock file | `./frontend/pnpm-lock.yaml` |
| `package_name` | Package name from package.json | `my-app` |
| `package_version` | Package version from package.json | `1.0.0` |
| `turbo_available` | Whether Turborepo configuration is available | `true` |
| `package_json_path` | Resolved path to package.json file | `./frontend/package.json` |

## Node Version Granularity

The `node_version_granularity` input controls how the Node.js version is formatted:

- **major**: `18` (from `18.2.1`)
- **minor**: `18.2` (from `18.2.1`)
- **patch**: `18.2.1` (from `18.2.1`) - *default*

## Requirements

Your `package.json` must include:

```json
{
  "engines": {
    "node": "18.2.1"
  },
  "packageManager": "pnpm@8.15.0"
}
```

## Supported Package Managers

- **npm**: `package-lock.json`
- **pnpm**: `pnpm-lock.yaml`
- **yarn**: `yarn.lock`
- **bun**: `bun.lockb`
- **others**: `{manager}.lock` (fallback)

## Testing

Run the BATS tests:

```bash
cd extract-package-info
bats test/extract-package-info.bats
```

## Example Scenarios

### Basic Usage
```yaml
- uses: your-org/infra-github-actions-mantrachain/extract-package-info@main
```

### Monorepo with Custom Path
```yaml
- uses: your-org/infra-github-actions-mantrachain/extract-package-info@main
  with:
    working_directory: 'apps/frontend'
    node_version_granularity: 'major'
```

### Docker Image Node Version
```yaml
- id: package-info
  uses: your-org/infra-github-actions-mantrachain/extract-package-info@main
  with:
    node_version_granularity: 'major'

- name: Build Docker image
  run: |
    docker build \
      --build-arg NODE_VERSION=${{ steps.package-info.outputs.node_version }} \
      .
```
