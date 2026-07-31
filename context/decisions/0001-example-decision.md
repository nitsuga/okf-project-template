---
type: Decision
title: Adopt the OKF-based documentation workflow
decision_status: accepted
tags: [decision, meta, docs]
generated:
  by: <actor>
  at: 2000-01-01T00:00:00Z
sources:
  - resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: Open Knowledge Format (OKF) v0.2 specification
fork: 1
---

<!-- [EXAMPLE — keep or replace] This ADR demonstrates the format (frontmatter +
     the body sections below). It also happens to record a real decision: that
     this project uses this doc workflow. Keep it as your ADR 0001, or delete it
     and write your own first decision. -->

# Context

A new project needs a place for its working knowledge, its decisions, and its
plan that an AI agent can maintain across sessions without the docs drifting out
of sync. Ad-hoc notes rot: history, decisions, and open work get restated in
several files, and the copies diverge.

# Decision

Adopt the `okf-project-template` workflow: an [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
knowledge bundle in `context/`, a decision register (ADRs) under
`context/decisions/`, a volatile plan in `planning/`, human docs in `docs/`, and
immutable inputs in `references/` — governed by the planning-hygiene rules in
`AGENTS.md` (one job per doc; history → `log.md`; no live tallies; closing an
item scrubs its forward-looking mentions).

# Alternatives considered

- **Ad-hoc Markdown notes** — no structure; duplication and drift set in quickly.
- **A wiki / external tool** — lives outside the repo, so it desyncs from the code
  and isn't in the agent's default context.
- **Only ADRs, no living plan** — records decisions but loses "what now / what
  next" and present state.

# Consequences

- Knowledge, decisions, and plan each have one home; an agent knows where to read
  and write.
- Some upfront discipline (write the ADR, update the register + log + PROGRESS).
- The rules must be understood, not just followed — see
  [`workflow-rationale`](../workflow-rationale.md).

# Assumptions / open questions

- Targets OKF v0.2; revisit on a new OKF version. The v0.1→v0.2 bump cost two
  field renames (`timestamp` → `generated`, body `# Citations` → `sources`), so
  a future bump is expected to be cheap but not free.

# Citations

- OKF v0.2 spec (frontmatter above) — the `context/` bundle format: the required
  `type` key, the reserved `index.md` / `log.md`, and the trust families this
  bundle uses sparingly.
- [Conventions](../CONVENTIONS.md) § Decisions — why the ADR state field is
  `decision_status` rather than `status` (v0.2 claims `status` for document
  lifecycle).
- [Why these rules](../workflow-rationale.md) — the failure mode behind each
  planning-hygiene rule this workflow imposes.
