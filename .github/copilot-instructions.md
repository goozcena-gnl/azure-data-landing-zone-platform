# GitHub Copilot Instructions

Read and follow `AGENTS.md` as the repository-wide engineering and trust contract.

For Copilot-specific work:
- keep changes narrowly scoped and inspect the existing validation path before editing;
- preserve PLAN -> APPLY integrity, OIDC/Entra authentication, and protected-environment assumptions;
- do not weaken Terraform, security, backend, policy, or documentation checks to obtain a green PR;
- distinguish implemented, statically validated, planned, deployed, and runtime-validated states;
- never run or propose autonomous Azure mutations as proof of correctness;
- leave merge, release, apply, destroy, AKS mutation, and environment authorization to a human.
