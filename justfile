# GitHub Actions local testing with act
# https://github.com/nektos/act

# Default recipe - show available commands
default:
    @just --list

# Setup act secrets file from example
setup-secrets:
    @if [ ! -f .secrets ]; then \
        echo "Creating .secrets from .secrets.example..."; \
        cp .secrets.example .secrets; \
        echo "✅ Created .secrets file"; \
        echo "⚠️  Please edit .secrets with your actual values"; \
    else \
        echo "✅ .secrets file already exists"; \
    fi

# Test extract-package-info action
test-extract-package-info:
    act push -W .github/workflows/extract-package-info.yml

# Test manage-cloudflare-zta-app action (requires secrets)
test-cloudflare-zta: setup-secrets
    act push --secret-file .secrets -W .github/workflows/manage-cloudflare-zta-app.yml

# Test all workflows
test-all: setup-secrets
    @echo "Testing extract-package-info..."
    @just test-extract-package-info
    @echo "Testing cloudflare-zta-app..."
    @just test-cloudflare-zta

# List all available workflows
list-workflows:
    @echo "Available workflows:"
    @find .github/workflows -name "*.yml" -o -name "*.yaml" | sort

# Clean up act cache and artifacts
clean:
    @echo "Cleaning up act cache..."
    @rm -rf /tmp/act-*
    @echo "✅ Cleaned up act temporary files"

# Validate all GitHub Actions workflows
validate-workflows:
    @echo "Validating GitHub Actions workflows..."
    @for file in .github/workflows/*.yml .github/workflows/*.yaml; do \
        if [ -f "$$file" ]; then \
            echo "Validating $$file..."; \
            act --dryrun -W "$$file" > /dev/null 2>&1 || echo "❌ $$file has issues"; \
        fi; \
    done
    @echo "✅ Workflow validation complete"

# Show act version and configuration
info:
    @echo "Act version:"
    @act --version
    @echo ""
    @echo "Available workflows:"
    @just list-workflows
    @echo ""
    @echo "Secrets file status:"
    @if [ -f .secrets ]; then \
        echo "✅ .secrets exists"; \
    else \
        echo "❌ .secrets missing (run 'just setup-secrets')"; \
    fi
