# Rust Lint Action

A GitHub Action to run Rust linter (cargo clippy) on a specific package or entire workspace.

## Description

This action runs `cargo clippy` with customizable lint levels to check your Rust code for common mistakes, style issues, and potential improvements. It can target either a specific package within a workspace or the entire workspace.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `package_name` | ✅ | `''` | The specific package to lint. If empty, lints the whole workspace. |
| `deny_level` | ❌ | `warnings` | The lint level to deny (e.g., `warnings`, `clippy::all`, `clippy::correctness`). |

## Usage

### Basic usage (lint entire workspace)

```yaml
- name: Lint Rust code
  uses: ./rust-lint
  with:
    package_name: ''
    deny_level: 'warnings'
```

### Lint specific package

```yaml
- name: Lint specific package
  uses: ./rust-lint
  with:
    package_name: 'my-package'
    deny_level: 'warnings'
```

### Use stricter lint level

```yaml
- name: Lint with all clippy rules
  uses: ./rust-lint
  with:
    package_name: ''
    deny_level: 'clippy::all'
```

## Example Workflow

```yaml
name: Rust Lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Lint Rust code
        uses: ./rust-lint
        with:
          package_name: ''
          deny_level: 'warnings'
```

## Deny Levels

Common deny levels you can use:

- `warnings` - Deny all warnings (default)
- `clippy::all` - Deny all clippy lints
- `clippy::correctness` - Deny correctness-related lints
- `clippy::style` - Deny style-related lints
- `clippy::complexity` - Deny complexity-related lints
- `clippy::perf` - Deny performance-related lints

## Dependencies

This action includes:
- Code checkout
- Rust toolchain setup (stable)
- Cargo dependency caching

## What it does

1. Checks out your code
2. Sets up the stable Rust toolchain
3. Caches cargo dependencies for faster builds
4. Runs `cargo clippy` with the specified deny level:
   - If `package_name` is provided: `cargo clippy -p <package_name> -- -D <deny_level>`
   - If `package_name` is empty: `cargo clippy --all-targets --all-features -- -D <deny_level>`