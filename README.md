# Infrastructure GitHub Actions - MantraChain

A collection of reusable GitHub Actions for MantraChain's infrastructure automation and deployment workflows.

## 📁 Actions Overview

### [🔄 Trigger Workflow](./trigger-workflow/)
Triggers and monitors workflows in remote repositories with comprehensive status tracking.

### [🔍 Monitor Terraform Workspace](./monitor-terraform-workspace/)
Monitors Terraform Cloud workspace runs with detailed status reporting and error handling.

### [📦 Extract Package Info](./extract-package-info/)
Extracts Node.js and package manager information from `package.json` files with support for multiple package managers.

### [🦀 Rust Lint](./rust-lint/)
Runs Rust linter (cargo clippy) on a specific package or entire workspace with customizable lint levels.

### [🧪 Rust Test](./rust-test/)
Runs Rust tests (cargo test) on a specific package or entire workspace.

## 🧪 Local Testing with Act

This repository includes local testing capabilities using [act](https://github.com/nektos/act) and [just](https://github.com/casey/just).

### Prerequisites

```bash
# Install act (GitHub Actions runner)
# macOS
brew install act

# Ubuntu/Debian
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Install just (command runner)
# macOS
brew install just

# Ubuntu/Debian
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
```

### Setup

1. **Create secrets file**:
   ```bash
   just setup-secrets
   # Edit .secrets with your actual token values
   ```

2. **Test individual actions**:
   ```bash
   # Test extract-package-info (no secrets required)
   just test-extract-package-info
   
   # Test cloudflare-zta-app (requires secrets)
   just test-cloudflare-zta
   ```

3. **Test all workflows**:
   ```bash
   just test-all
   ```

### Available Commands

| Command | Description |
|---------|-------------|
| `just setup-secrets` | Create .secrets file from example |
| `just test-extract-package-info` | Test extract-package-info action |
| `just test-cloudflare-zta` | Test cloudflare-zta-app action |
| `just test-rust-lint` | Test rust-lint action |
| `just test-rust-test` | Test rust-test action |
| `just test-all` | Test all workflows |
| `just list-workflows` | List available workflows |
| `just test-workflow <path>` | Test specific workflow |
| `just validate-workflows` | Validate all workflows |
| `just clean` | Clean up act cache |
| `just info` | Show act version and status |

### Testing Examples

```bash
# Test specific workflow with custom path
just test-workflow .github/workflows/extract-package-info.yml

# Test rust actions
just test-rust-lint
just test-rust-test

# Test workflow that requires secrets
just test-workflow-with-secrets .github/workflows/manage-cloudflare-zta-app.yml

# Validate all workflows without running them
just validate-workflows

# Get information about your setup
just info
```

### Secrets Configuration

The `.secrets` file (created from `.secrets.example`) contains:

- `GITHUB_TOKEN`: GitHub personal access token
- `TF_API_TOKEN`: Terraform Cloud API token  
- `CLOUDFLARE_API_TOKEN`: Cloudflare API token
- `CLOUDFLARE_ACCOUNT_ID`: Cloudflare account ID
- And other tokens as needed

**Important**: Never commit `.secrets` to version control. It's automatically ignored by `.gitignore`.

## 🔧 Development

### Adding New Actions

1. Create a new directory for your action
2. Add the action implementation
3. Create tests (using BATS for shell scripts)
4. Add workflow for testing
5. Update this README

### Testing Actions

Each action should include:
- Unit tests (BATS for shell scripts, appropriate framework for others)
- Integration tests via GitHub Actions workflows
- Local testing support via act

### Code Standards

- **Shell Scripts**: Follow shell best practices, include error handling
- **Documentation**: Each action must have a comprehensive README
- **Testing**: All actions must have test coverage
- **Versioning**: Use semantic versioning for releases

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Act Documentation](https://github.com/nektos/act)
- [Just Documentation](https://github.com/casey/just)
- [BATS Testing Framework](https://github.com/bats-core/bats-core)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Ensure all tests pass locally (`just test-all`)
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](./LICENSE) file for details.
