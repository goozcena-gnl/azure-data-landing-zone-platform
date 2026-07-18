.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help format lint validate terraform-test security backend-test test aks-preflight plan-lab deploy-lab smoke-test destroy-lab docs-check package-release

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

format: ## Format Terraform files
	terraform fmt -recursive

lint: ## Run repository, YAML, shell, and Terraform lint checks
	bash ./scripts/lint.sh

validate: ## Initialize Terraform without the remote backend and validate
	bash ./scripts/terraform-validate.sh

terraform-test: ## Run provider-mocked Terraform input tests
	TF_DATA_DIR="$${TF_DATA_ROOT:-$${XDG_CACHE_HOME:-$${HOME}/.cache}/azure-data-landing-zone-platform/terraform}/landing-zone" terraform -chdir=infra/landing-zone test -no-color

security: ## Run Checkov and deterministic secret-pattern scanning
	bash ./scripts/security-scan.sh

backend-test: ## Run fixture-only backend helper regressions
	bash ./terraform_backend_setup/tests/regression.sh

test: lint validate terraform-test security backend-test docs-check ## Run all non-deployment checks

aks-preflight: ## Run read-only AKS subscription, SKU, quota, and identity checks
	bash ./scripts/aks-preflight.sh

plan-lab: ## Create a reviewed lab plan
	bash ./scripts/plan-lab.sh

deploy-lab: ## Apply the exact reviewed lab plan
	bash ./scripts/deploy-lab.sh

smoke-test: ## Verify Azure and AKS lab health
	bash ./scripts/smoke-test.sh

destroy-lab: ## Destroy the disposable lab
	bash ./scripts/destroy-lab.sh

docs-check: ## Validate local Markdown links
	python3 scripts/check-doc-links.py

package-release: ## Build a clean archive (set OUTPUT_DIR outside the repository)
	bash ./scripts/package-release.sh --output-dir "$${OUTPUT_DIR:?Set OUTPUT_DIR outside the repository}"
