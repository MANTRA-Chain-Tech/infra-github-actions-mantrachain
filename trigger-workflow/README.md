# Trigger Workflow Action

A GitHub Action to trigger and monitor workflows in remote repositories. This action allows you to dispatch workflows in other repositories and optionally wait for their completion.

## Features

- Trigger workflows in remote repositories
- Monitor workflow execution status
- Support for workflow inputs/parameters
- Configurable timeout and polling intervals
- Detailed logging and error handling

## Usage

### Basic Usage

```yaml
- name: Trigger remote workflow
  uses: ./trigger-workflow
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    repository: 'owner/repo-name'
    workflow: 'deploy.yml'
    ref: 'main'
```

### Advanced Usage with Monitoring

```yaml
- name: Trigger and monitor workflow
  uses: ./trigger-workflow
  with:
    token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
    repository: 'owner/repo-name'
    workflow: 'deploy.yml'
    ref: 'main'
    inputs: |
      environment: production
      version: v1.2.3
    wait: true
    timeout: 300
    poll-interval: 30
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `token` | GitHub token with appropriate permissions | Yes | - |
| `repository` | Target repository in format 'owner/repo' | Yes | - |
| `workflow` | Workflow filename or ID to trigger | Yes | - |
| `ref` | Git reference (branch, tag, or SHA) | No | `main` |
| `inputs` | Workflow inputs as YAML/JSON string | No | `{}` |
| `wait` | Wait for workflow completion | No | `false` |
| `timeout` | Maximum wait time in seconds | No | `300` |
| `poll-interval` | Polling interval in seconds | No | `30` |

## Outputs

| Output | Description |
|--------|-------------|
| `workflow-id` | ID of the triggered workflow run |
| `workflow-url` | URL to the workflow run |
| `status` | Final status of the workflow (if monitored) |
| `conclusion` | Conclusion of the workflow (if monitored) |

## Prerequisites

### Token Permissions

The GitHub token needs the following permissions:

- `actions:write` - To trigger workflows
- `actions:read` - To monitor workflow status
- Repository access to the target repository

### Personal Access Token (Recommended)

For cross-repository triggers, use a Personal Access Token with:
- `repo` scope for private repositories
- `public_repo` scope for public repositories
- `workflow` scope to trigger workflows

## Examples

### Trigger Deployment Workflow

```yaml
name: Deploy to Production
on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger deployment
        uses: ./trigger-workflow
        with:
          token: ${{ secrets.DEPLOY_TOKEN }}
          repository: 'company/infrastructure'
          workflow: 'deploy-production.yml'
          ref: ${{ github.ref }}
          inputs: |
            service: my-service
            version: ${{ github.ref_name }}
            environment: production
          wait: true
          timeout: 600
```

### Matrix Strategy with Multiple Repositories

```yaml
strategy:
  matrix:
    repo: ['repo1', 'repo2', 'repo3']
steps:
  - name: Trigger workflows
    uses: ./trigger-workflow
    with:
      token: ${{ secrets.GITHUB_TOKEN }}
      repository: 'owner/${{ matrix.repo }}'
      workflow: 'ci.yml'
      ref: 'main'
```

### Conditional Workflow Trigger

```yaml
- name: Trigger if tests pass
  if: success()
  uses: ./trigger-workflow
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    repository: 'owner/deployment-repo'
    workflow: 'deploy.yml'
    ref: 'main'
    inputs: |
      commit-sha: ${{ github.sha }}
      triggered-by: ${{ github.actor }}
```

## Error Handling

The action will fail if:
- The target repository doesn't exist or isn't accessible
- The workflow file doesn't exist
- The token lacks required permissions
- The workflow fails (when `wait: true`)
- Timeout is reached (when `wait: true`)

## Development

### Local Testing

```bash
npm install
npm test
```

### Building

```bash
npm run build
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For issues and questions:
- Create an issue in this repository
- Check existing issues for solutions
- Review the GitHub Actions documentation
