# Manage Cloudflare Zero Trust Access Application

A GitHub Action to create and delete Cloudflare Zero Trust Access applications with idempotent operations.

## Features

- ✅ Create Cloudflare Zero Trust Access applications
- ✅ Delete applications (idempotent - no error if app doesn't exist)
- ✅ Check if applications exist
- ✅ Configurable policies with precedence
- ✅ Comprehensive error handling
- ✅ BATS testing included

## Usage

### Basic Example

```yaml
- name: Create Cloudflare Access App
  uses: ./manage-cloudflare-zta-app
  with:
    action: 'create'
    app_name: 'My Application'
    domain: 'myapp.example.com'
    cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    allowed_idp: 'bc3fa177-7ef6-45c1-999b-1eb49b0c8edf'
```

### Delete Application

```yaml
- name: Delete Cloudflare Access App
  uses: ./manage-cloudflare-zta-app
  with:
    action: 'delete'
    app_name: 'My Application'
    domain: 'myapp.example.com'
    cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

### Custom Policies

```yaml
- name: Create App with Custom Policies
  uses: ./manage-cloudflare-zta-app
  with:
    action: 'create'
    app_name: 'My Application'
    domain: 'myapp.example.com'
    cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    policies: 'policy-id-1:1,policy-id-2:2,policy-id-3:3'
    allowed_idp: 'bc3fa177-7ef6-45c1-999b-1eb49b0c8edf'
```

### Using Output

```yaml
- name: Create Cloudflare Access App
  id: create-app
  uses: ./manage-cloudflare-zta-app
  with:
    action: 'create'
    app_name: 'My Application'
    domain: 'myapp.example.com'
    cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    allowed_idp: 'bc3fa177-7ef6-45c1-999b-1eb49b0c8edf'

- name: Use App ID
  run: echo "Created app with ID: ${{ steps.create-app.outputs.app_id }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `action` | Action to perform (`create` or `delete`) | Yes | `create` |
| `app_name` | Name of the application | Yes | - |
| `domain` | Domain for the application | Yes | - |
| `cloudflare_account_id` | Cloudflare Account ID | Yes | - |
| `cloudflare_api_token` | Cloudflare API Token | Yes | - |
| `policies` | Policies in format `POLICY_ID1:PRECEDENCE1,POLICY_ID2:PRECEDENCE2` | No | Default MantraChain policies |
| `allowed_idp` | Allowed Identity Provider ID | Yes | `bc3fa177-7ef6-45c1-999b-1eb49b0c8edf` |

Notes:
- allowed_idp value can be found in : `Cloudflare > Zero Trust > Settings > Authentication > Login methods > Your chosen IDP > Edit`, and copy the ID from the URL suffix.

## Outputs

| Output | Description |
|--------|-------------|
| `app_id` | The ID of the created/managed application (empty for delete action) |

## Policy Format

Policies should be provided in the format: `POLICY_ID:PRECEDENCE,POLICY_ID:PRECEDENCE`

Example: `60c7003f-6f64-4e86-9566-edc94e4079d6:1,dc27b7f2-952c-4451-9354-c5ae9c9a45db:2`

## Default Policies

The action uses these default MantraChain policies if none are specified:
- `1a3e0a22-040d-4941-a899-a370548e5bd5` with precedence 1
- `66f03940-062b-4d65-9c32-7c714ac89194` with precedence 2

## Behavior

### Create Action
- If the application already exists, it will be deleted and recreated (idempotent)
- Returns the new application ID as output
- Fails if creation fails

### Delete Action
- If the application exists, it will be deleted
- If the application doesn't exist, the action succeeds without error
- Returns empty app_id as output
- Fails only if deletion of an existing app fails

## Prerequisites

1. Cloudflare API Token with appropriate permissions:
   - Zone:Zone:Read
   - Account:Cloudflare Access:Edit

2. Cloudflare Account ID

## Development

### Running Tests

The action includes comprehensive BATS tests:

```bash
# Install bats if not already installed
npm install -g bats

# Run integration tests (requires real Cloudflare API token)
export CLOUDFLARE_API_TOKEN="your-real-api-token"
bats test/integration.bats

# Run all tests
bats test/
```

#### Integration Tests

Integration tests use the real Cloudflare account ID `2ff8e4962cfd414617e13d4c503e09ae` and require:

1. `CLOUDFLARE_API_TOKEN` environment variable set with a valid token
2. API token permissions:
   - Zone:Zone:Read
   - Account:Cloudflare Access:Edit
3. Access to create/delete applications on the test domain `integration-test.mantrachain.io`

Integration tests are idempotent and include cleanup.

**Note**: Integration tests will create and delete real Cloudflare Access applications during testing.

### Direct Script Usage

You can also use the script directly:

```bash
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
export CLOUDFLARE_API_TOKEN="your-api-token"

./manage.sh --action create --name "My App" --domain "myapp.com" --policies "policy-id:1" --allowed-idp "abcd-...-efgh"
```