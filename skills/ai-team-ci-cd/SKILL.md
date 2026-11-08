---
name: ai-team-ci-cd
description: Configure or review build, verification, artifact promotion and release pipelines with reproducible source and bounded permissions. Use for CI/CD, packaging and authorized Git publication.
---

# CI and release

Detect the repository host, stack, target environments, existing pipeline and release
authorization. Do not invent deployment credentials or a production host.

- PR checks run relevant lint/typecheck, tests and build using the lockfile and supported
  runtime. Toolkit tests should not require a live GPU, model download or account login.
- Pin third-party actions to verified full commit SHAs; keep tokens read-only by default,
  avoid secrets on untrusted PR code and avoid executing such code in privileged workflows.
- Package only an explicit allowlist of release files; exclude credentials, machine state,
  prompts, model weights and temporary connection details. Verify the extracted package.
- Promote the same verified artifact to staging/production. Define smoke/health checks,
  monitoring, migration order and rollback appropriate to the real deployment target.
- For authorized Git publication, inspect remote state and local changes first; never
  force-push over existing work. Verify exact-final-source checks before commit/push and
  recheck affected artifacts after edits. Follow any project-specific Docker release gate.
- Report commit and push separately with branch and SHA. A YAML file is not proof of a
  hosted CI run; a successful push is not proof of production deployment.
