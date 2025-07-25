# Rust Test Action

A GitHub Action to run Rust tests (cargo test) on a specific package or entire workspace.

## Description

This action runs `cargo test` to execute your Rust test suites. It can target either a specific package within a workspace or the entire workspace, making it flexible for both single-package projects and multi-package workspaces.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `package_name` | ✅ | N/A | The specific package to test. If empty, tests the whole workspace. |

## Usage

### Basic usage (test entire workspace)

```yaml
- name: Test Rust code
  uses: ./rust-test
  with:
    package_name: ''
```

### Test specific package

```yaml
- name: Test specific package
  uses: ./rust-test
  with:
    package_name: 'my-package'
```

## Example Workflow

```yaml
name: Rust Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run tests
        uses: ./rust-test
        with:
          package_name: ''
```

## Example Multi-Job Workflow

```yaml
name: Rust CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-workspace:
    name: Test entire workspace
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Test workspace
        uses: ./rust-test
        with:
          package_name: ''

  test-individual-packages:
    name: Test individual packages
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package: [package-a, package-b, package-c]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Test ${{ matrix.package }}
        uses: ./rust-test
        with:
          package_name: ${{ matrix.package }}
```

## Dependencies

This action includes:
- Code checkout
- Rust toolchain setup (stable)
- Cargo dependency caching

## What it does

1. Checks out your code
2. Sets up the stable Rust toolchain
3. Caches cargo dependencies for faster builds
4. Runs `cargo test`:
   - If `package_name` is provided: `cargo test --package <package_name>`
   - If `package_name` is empty: `cargo test --workspace`

## Test Output

The action will:
- Run all unit tests
- Run all integration tests
- Run all documentation tests
- Display test results and any failures
- Exit with a non-zero code if any tests fail