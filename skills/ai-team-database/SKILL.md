---
name: ai-team-database
description: Design or review persistence schemas, query changes and migrations with integrity, tenant isolation and recoverable rollout. Use when durable data or database behavior changes.
---

# Database and persistence

Inspect the actual schema, engine/version, migration history and callers. Do not invent
a database layer for a project without persistence. Local AI can draft bounded migrations;
Codex reviews integrity and tests against the relevant database engine.

- State entity identity, ownership, uniqueness, nullability and referential constraints.
- Decide transaction and concurrency semantics; make retried progress/event writes safe.
- Scope tenant reads and writes explicitly; test cross-tenant denial and deletion behavior.
- Match indexes to real query patterns and inspect plans when performance is the task.
- Prefer expand/backfill/contract for incompatible changes; define old/new code compatibility.
- Before destructive production changes, prepare backup/restore, data validation and a
  realistic rollback or forward-repair plan. Authorization must cover the actual mutation.
- Test migration on representative nonproduction data, duplicate/null/invalid input and
  recovery. SQLite mocks do not prove PostgreSQL/MySQL behavior or production readiness.
- Record schema version, affected callers and rollout order; keep generated SQL reviewable.
