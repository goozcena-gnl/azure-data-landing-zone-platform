---
applyTo: "**/*.tf,**/*.tfvars,**/*.hcl,infra/**,terraform_backend_setup/**"
---

# Terraform and Azure IaC Instructions

- Preserve remote-state protections and Microsoft Entra data-plane authorization.
- Do not introduce storage keys, long-lived Azure secrets, or kubeconfig outputs.
- Prefer deterministic plans and exact reviewed-plan application semantics.
- Keep optional/high-cost resources disabled by default unless the existing architecture explicitly says otherwise.
- Run formatting, validation, provider-mocked tests, TFLint initialization/checks, and security scanning for relevant changes.
- Static validation is not evidence that Azure resources were deployed or destroyed.
