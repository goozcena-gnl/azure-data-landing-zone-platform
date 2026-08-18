.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help bootstrap doctor format lint lint-strict lint-best-effort validate terraform-test security backend-test bats-test tooling-test test test-strict test-container aks-preflight plan-lab deploy-lab smoke-test destroy-lab docs-check package-release

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap: ## Install the supported user-local validation toolchain
	bash ./scripts/bootstrap-local.sh

doctor: ## Verify strict local-validation prerequisites without network or cloud access
	bash ./scripts/doctor.sh

format: ## Format Terraform files
	terraform fmt -recursive

lint: lint-strict ## Run strict repository, YAML, shell, and Terraform lint checks

lint-strict: ## Fail when any required lint tool is missing
	bash ./scripts/lint.sh --strict

lint-best-effort: ## Run available linters and report explicit skips
	bash ./scripts/lint.sh --best-effort

validate: ## Initialize Terraform without the remote backend and validate
	bash ./scripts/terraform-validate.sh

terraform-test: ## Run provider-mocked Terraform input tests
	TF_DATA_DIR="$${TF_DATA_ROOT:-$${XDG_CACHE_HOME:-$${HOME}/.cache}/azure-data-landing-zone-platform/terraform}/landing-zone" terraform -chdir=infra/landing-zone init -backend=false -input=false -no-color
	TF_DATA_DIR="$${TF_DATA_ROOT:-$${XDG_CACHE_HOME:-$${HOME}/.cache}/azure-data-landing-zone-platform/terraform}/landing-zone" terraform -chdir=infra/landing-zone test -no-color

security: ## Run Checkov and deterministic secret-pattern scanning
	bash ./scripts/security-scan.sh

backend-test: ## Run fixture-only backend helper regressions
	bash ./terraform_backend_setup/tests/regression.sh

bats-test: ## Run local-environment and existing backend Bats tests
	bats tests/*.bats terraform_backend_setup/tests/terraform_setup.bats

tooling-test: ## Run tool-manifest and version-drift unit tests
	python3 -m unittest -v tests/test_tool_versions.py

test: test-strict ## Run all strict non-deployment checks

test-strict: doctor lint-strict tooling-test validate terraform-test security backend-test bats-test docs-check ## Run CI-equivalent non-deployment checks

test-container: ## Build the Dev Container image and run strict validation in it
	bash ./scripts/test-container.sh

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
