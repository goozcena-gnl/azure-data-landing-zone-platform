.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help format lint validate security test plan-lab deploy-lab smoke-test destroy-lab docs-check

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

format: ## Format Terraform files
	terraform fmt -recursive

lint: ## Run repository, YAML, shell, and Terraform lint checks
	./scripts/lint.sh

validate: ## Initialize Terraform without the remote backend and validate
	./scripts/terraform-validate.sh

security: ## Run Checkov and deterministic secret-pattern scanning
	./scripts/security-scan.sh

test: lint validate security docs-check ## Run all non-deployment checks

plan-lab: ## Create a reviewed lab plan
	./scripts/plan-lab.sh

deploy-lab: ## Apply the exact reviewed lab plan
	./scripts/deploy-lab.sh

smoke-test: ## Verify Azure and AKS lab health
	./scripts/smoke-test.sh

destroy-lab: ## Destroy the disposable lab
	./scripts/destroy-lab.sh

docs-check: ## Validate local Markdown links
	python3 scripts/check-doc-links.py
