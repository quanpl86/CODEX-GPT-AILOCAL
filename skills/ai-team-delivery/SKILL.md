---
name: ai-team-delivery
description: Coordinate substantial software work across ChatGPT planning, local model implementation, and Codex review/testing using bounded tasks and evidence. Use for multi-step project delivery or refactoring, not simple factual questions.
---

# Delivery and architecture

Read the project's AGENTS.md and work board; preserve its stack and existing decisions.
Use ChatGPT for phase planning/architecture and milestone review, local AI for bounded
code/test changes, Codex for review, integration, verification and Git. These are roles,
not permission to spawn agents, contact external services or change account settings.

- For a small low-risk change, implement locally and verify without a planning roundtrip.
- For larger work, record scope, interfaces, acceptance, file ownership, dependencies and
  meaningful phases in the existing board. Prefer one small ready task over a broad epic.
- Route by difficulty and risk. Use MiMo for web/game/code tasks; North for bounded agent
  or learning flow work when resources permit. Critical auth/data/migration decisions and
  two failed local repair rounds justify a cloud escalation of that part only.
- Local coding output belongs in staging. Use the project's reviewed apply mechanism;
  never let generated text act as a shell instruction or claim verification.
- Fix underlying causes. Search for existing modules before adding abstractions/dependencies;
  avoid redundant helpers, broad rewrites and catch-and-ignore patches.
- One writer per file. Refactor in testable steps with explicit API/schema compatibility.
- Update the board at phase changes, completed work and blockers. Handoffs include task ID,
  role, changed contract/files, evidence, unresolved issue and requested next action.
- Finish with targeted tests/runtime evidence; distinguish implemented, reviewed, verified
  and released. Do not label a system production-ready from a smoke test.

If the workspace has AI-LOCAL helpers, use Invoke-LocalCoder.ps1 and return test failures
through ReviewReport. If not, adapt to the tools actually present; do not invent an API.
