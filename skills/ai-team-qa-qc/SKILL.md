---
name: ai-team-qa-qc
description: Verify implemented changes with risk-based tests, independent review and real browser/runtime evidence, including external Chrome when requested. Use for acceptance, regressions and release quality checks.
---

# QA and quality control

Start from the acceptance criteria and changed behavior. Identify what the existing
tests establish and what still needs real execution. Codex owns verification; a local
model's proposed tests/results are not evidence until executed independently.

- Run the smallest meaningful checks first, then integration/build/runtime checks required
  by the change. Add regression tests for concrete failure modes, not implementation mirrors.
- Cover the main path plus risk-specific error, access, retry, race and persistence cases.
- For web/UI changes, run the final source on external Chrome if required: real interaction,
  console/network, mobile width, keyboard and refresh/deep-link behavior as relevant.
- Test the actual built image/artifact when the project deploys one; source tests do not
  establish Docker/runtime or browser visual correctness.
- Review diff for correctness, scope, maintainability, stale/dead code and secret exposure.
- Report each failure with reproduction, expected/actual, file/contract evidence and narrow
  repair request. Send the report to the implementer; bound repeated local repair rounds.
- Mark unavailable environments and untested flows explicitly. Do not fabricate screenshots,
  measurements, CI success, security guarantees or production certification.

No application runtime means N/A for that runtime gate, not a made-up passing fixture.
