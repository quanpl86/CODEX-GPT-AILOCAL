---
name: ai-team-backend
description: Implement or review API and service changes with explicit contracts, authorization boundaries, idempotency, observability and maintainable modules. Use for backend behavior and integrations, not database-only migrations.
---

# Backend engineering

Read the API contracts, auth/tenant boundary and adjacent implementation before editing.
Match the framework and existing service structure. Local AI receives a bounded endpoint
or service task; Codex owns integration tests and independent security/correctness review.

- Define request/response schemas, authorization, error semantics and side effects.
- Validate at boundaries and enforce tenant/object authorization server-side.
- Separate transport, domain logic and persistence when their responsibilities differ;
  avoid wrappers that only rename an existing operation.
- For mutating requests, consider retries, idempotency, transaction boundaries and concurrent
  writes. Use bounded timeout/retry with explicit failure propagation for external services.
- Prevent secret/PII logging, unsafe deserialization, injection and request-driven file paths.
- Add structured operational events and actionable errors without exposing internals to UI.
- Verify real integration behavior where practical; mocks alone cannot establish auth,
  database semantics or external compatibility. Exercise denied access and error paths.
- Document changed contracts and upgrade implications. Remove replaced logic instead of
  leaving parallel code paths without a migration reason.
