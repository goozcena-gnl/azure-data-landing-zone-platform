.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help format lint validate security test plan-lab deploy-lab smoke-test destroy-lab docs-check

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

format: ## Format Terraform files
	terraform fmt -recursive

lint: ## Run repository, YAML, shell, and Terraform lint checks
	bash ./scripts/lint.sh

validate: ## Initialize Terraform without the remote backend and validate
	bash ./scripts/terraform-validate.sh

security: ## Run Checkov and deterministic secret-pattern scanning
	bash ./scripts/security-scan.sh

test: lint validate security docs-check ## Run all non-deployment checks

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
