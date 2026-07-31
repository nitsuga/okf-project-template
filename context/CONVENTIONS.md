---
type: Conventions
title: Knowledge bundle conventions
description: How the context/ OKF bundle is structured, written, and maintained.
tags: [meta, okf, conventions]
generated:
  by: <actor>
  at: 2000-01-01T00:00:00Z
---

# Purpose

`context/` is the agent-facing knowledge base for this project, in
[OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
v0.2. It is the synthesis layer between immutable sources and the working agent:
knowledge is compiled here once and kept current, not re-derived each session.
The agent writes and maintains this directory; humans curate sources and direct
the work. On disagreement, the OKF spec wins over this doc.

**Where a rule in this file was itself decided by an ADR, cite it** on the spot —
`Decided in [NNNN-slug](./decisions/NNNN-slug.md).` The rule and the reasoning
that produced it then travel together, and the next agent tempted to "simplify" a
convention finds the argument before the edit rather than after. A rule whose ADR
nobody can find gets relitigated from scratch.

# Layout

| Path | Role |
|------|------|
| `../references/` | Immutable raw sources. Agent reads, never modifies. |
| `context/` | This bundle. Agent-owned synthesis. |
| `../docs/` | Human-facing authored guides (terse). Not agent-maintained. |
| `../planning/` | Project management (ROADMAP, PROGRESS). Transient; human + agent read/write. Not OKF concepts. |

# Frontmatter

Every concept `.md` carries YAML frontmatter. Required: `type` — the only key OKF
mandates. Recommended: `title`, `description`, `tags`, and `generated` (who
produced this, and when). Keep frontmatter minimal; OKF tolerates unknown keys
but they add noise.

```yaml
type: Concept
title: Short display name
description: One-sentence summary.
tags: [topic, phase-1]
generated:
  by: <actor>
  at: 2026-01-01T00:00:00Z
```

**Actors.** `generated.by` (and `verified[].by`) use the OKF actor convention:
`human:<id>` for people, `<producer>/<version>` for agents and tools (e.g.
`claude/opus-5`), `process:<id>` for automation. Trust tooling keys off the
`human:` prefix — use it only for genuine human authorship or review, not for
agent-written docs a human merely merged.

Optional families — add one only when it earns its keep:

| Field | Use for |
|------|------|
| `resource` | Canonical URI/path of the asset the concept describes. |
| `sources` | Machine-readable inputs the concept derives from. Per entry `resource` is required; `title`, `author` optional. See § Citations and `sources`. |
| `verified` | List of `{by, at}` checks confirming the doc still matches its sources. |
| `status` | **OKF document lifecycle**: `draft` / `stable` (default) / `deprecated`. Not the ADR state — see § Decisions. |
| `stale_after` | `YYYY-MM-DD` after which the doc should be re-checked. |

**Migrating from OKF v0.1:** `timestamp` was replaced by `generated: {by, at}`,
and the body `# Citations` list by frontmatter `sources`. Consumers may fall back
to the legacy fields, so an un-migrated doc still reads — but write new docs in
the v0.2 spelling.

# Type vocabulary

Open, not closed — new types may emerge. OKF tolerates unknown types, so an
emerging type breaks nothing; still, prefer an existing type if it fits. A
domain-neutral starter set (rename / add for your project):

| Type | Use for |
|------|---------|
| `Reference` | Synthesis of an external source (a spec, a standard, a prior-art repo). Cites the immutable original in `../references/`. |
| `Concept` | A piece of durable domain or design knowledge. |
| `Component` | A module / subsystem of the project. |
| `Decision` | Architecture decision record — the *why* of a resolved (or proposed) fork. |

OKF v0.2 also defines one type with spec-level semantics, `Attested Computation`
(a concept carrying `runtime` / `parameters` / `computation` / `executor` /
`attester`, so a value's meaning and its verifiable derivation live together).
Use it only if this project actually computes attested values; otherwise ignore it.

Keep this table to the types **actually in use**, and name the rest separately:

> _Anticipated but not yet used: `<Type>`; `<Type>` has an `index.md` section but
> no concepts yet._

That line is a forward-looking claim, so the scrub rule applies to it: when the
first concept of an anticipated type lands, move the type into the table above
and delete it from this note. Otherwise the vocabulary drifts into a wish list
and stops describing the bundle.

<!-- e.g. a data project might add `Dataset`; a standards-heavy one `Standard
     Reference`. Delete types you won't use. -->

# Decisions

A **fork** is a decision point — a branch in the design or plan that needs a
choice (the metaphor is a fork in the road; it has nothing to do with a git fork).
Forks are the unit the roadmap and the register track.

A `type: Decision` concept is an ADR: the *why* of a resolved (or proposed) fork
— context, alternatives considered, the choice, consequences. Carry a
`decision_status:` frontmatter field:

| `decision_status` | Meaning |
|---|---|
| `proposed` | Under deliberation; not yet adopted. |
| `accepted` | Resolved and in force. |
| `superseded` | Replaced by a later Decision (link it). |
| `deferred` | Parked; revisit later. |

**Why not `status:`?** OKF v0.2 claims `status` for *document* lifecycle
(`draft` / `stable` / `deprecated`) — a different axis from *decision* state: a
superseded ADR is a stable document you keep for the record. Since the spec wins
on disagreement (§ Purpose), the ADR field is `decision_status`, which OKF
tolerates as an unknown key. An ADR may still carry `status` in its OKF sense,
but rarely needs to.

Lifecycle: an open fork starts under **Open forks** in
[`../planning/ROADMAP.md`](../planning/ROADMAP.md) (`OPEN`). Once deliberated,
write the Decision in [`./decisions/`](./decisions/index.md) with
`decision_status: proposed`; on resolution set `accepted`, add its row to the **decided
register** [`./decisions/index.md`](./decisions/index.md) (fork # ↔ ADR ↔
status), and refresh present state in
[`../planning/PROGRESS.md`](../planning/PROGRESS.md). ROADMAP defers decided
forks to the register.

Record the decision in [`log.md`](./log.md) as a **single thin line** —
chronology + a link to the ADR. The ADR owns the rationale, so do **not** restate
the decision or its rejected alternatives in the log (that puts the same content
in three places). Add a *second* log line for one fork only on a genuine
cross-session gap (proposed in one session, accepted in a later one) or a
revision / supersede — **not** for a same-session propose→accept, which is one
event and gets one line.

## ADR format

- **Filename:** `NNNN-slug.md` — 4-digit zero-padded, hyphenated lowercase slug.
  Numbering is sequential by **creation order** (not the roadmap-fork number;
  they diverge). Monotonic; never reused (a superseded ADR keeps its number, the
  superseder takes the next).
- **Frontmatter:** `type: Decision`, `title`, `decision_status`, `tags` (include
  `decision`, a topic tag, optionally `phase-N`), `generated: {by, at}`, optional
  `sources:`, optional `fork:` (roadmap fork # for traceability).
- **Body:** `# Context` → `# Decision` → `# Alternatives considered` →
  `# Consequences` → `# Assumptions / open questions` → `# Citations`
  (specialized sections allowed between). Use `# Decision` always —
  `decision_status` carries proposed/accepted, so no header churn on accept.
- **Register:** [`./decisions/index.md`](./decisions/index.md) lists
  `Fork | ADR | Status`; updated on every status change.

# Citations and `sources`

v0.2 replaces the body `# Citations` list with frontmatter `sources`. Here, both
have a job, because they carry different things:

- **`sources:` (frontmatter)** — the machine-readable index of *external* inputs:
  a file under `../references/`, a spec URL. One entry per input, `resource`
  required. This is what a consumer reads first.
- **`# Citations` (body)** — the annotated bibliography: each entry says *why
  that source mattered to this doc*. Links to sibling concepts and ADRs
  (`[Title](./concept.md) § Section — what it supplied`) live here.

Keep the annotation. A bare `resource:` list records that a source was consulted;
the prose records what it decided — and that reasoning is the reason to keep an
ADR at all. Purely internal cross-references (other concepts, other ADRs) need no
`sources` entry; the body link is enough.

**Cite by stable anchor, not by position.** Name the section, clause, or heading
(`ST 0601 §6.3`, `SPEC.md § Conformance`) — never a line or page number of a
derived extract. Extracts get regenerated and revisions shift their numbering, so
a positional citation silently comes to point at the wrong text, which is worse
than a broken one: it still resolves, and it still looks right. Where a source in
`../references/` has a text extract beside it for grep/Read, that extract is a
reading aid, not a citable address — cite the source it came from.

# Subdirectories

Types stay flat in `context/` by default; the root `index.md` groups by type.
Split a type into its own subdir when flat-listing grows noisy (~10+ files) or
develops sub-structure, and give the subdir its own `index.md`. `decisions/` is
pre-created because ADRs accumulate and supersede (a register is useful
immediately).

# Linking

**Sibling-relative markdown, always**: `[Title](./concept.md)` within the bundle,
`../planning/…` / `../references/…` for targets outside it. One form, and it
resolves for all three readers — a person on GitHub, an editor, and an agent
following paths.

**Never root-absolute** (`](/concept.md)`). OKF v0.2 *recommends* this form
because it survives file moves, but that only holds for a consumer resolving
paths against the bundle root; GitHub, editors, and path-following agents all
resolve against the *site* root, where it points nowhere. The spec also lists
relative links as supported, so sibling-relative is fully conformant — this is a
choice between two allowed forms, not a divergence from the spec. Guard the move
-survival you give up with the link-check CI (see `README.md`), not with the
absolute form.

**The `[[slug]]` variant.** Wikilinks resolve by name rather than path, so they
survive a file moving or a type being split into its own subdir (§ Subdirectories
expects that split). They render as literal text on GitHub, which is a real cost
for human readers and a non-cost inside an agent-facing bundle. A project with a
citation-dense bundle may reasonably adopt the two-form rule instead: **target
inside `context/` → `[[slug]]`, target outside → relative markdown**. Keep that
boundary structural — "whichever a person is more likely to read" is decided
afresh at every link, so it drifts.

Sibling-relative-everywhere is the default here because one form needs no
decision per link and no non-standard syntax, not because the variant is unsafe:
in the project that uses it, every wikilink resolves. Whichever you pick, the
link-check CI verifies both forms, so neither is the unchecked one — and say
which you chose in this section, so the next agent doesn't mix them by accident.

Relationship semantics — references, nests-in, depends-on — live in the
surrounding prose; the link itself is untyped. Broken links are not errors; they
may be not-yet-written knowledge.

# Reserved files

`index.md` — directory listing for progressive disclosure. No frontmatter except
`okf_version: "0.2"` at the bundle root. `log.md` — chronological change history,
newest first, ISO `YYYY-MM-DD` headings. Both agent-maintained.

# Operations

**Ingest.** A new source (a spec, a prior-art repo) enters `../references/` or is
fetched. Read it, extract key facts, write a concept doc, update relevant
existing concepts and cross-links, add an `index.md` entry, append a `log.md`
line. One source may touch several docs.

**Query.** Read `index.md` first to find relevant concepts, drill in, synthesize
with citations back to `../references/` or external URLs. File valuable query
results back as new concepts so explorations compound.

**Lint.** Periodically check for: contradictions between docs, stale claims
superseded by newer sources, **forward-looking claims a later change resolved**
(an "open decision" / "candidate" / "Next" item that's since been decided or done
— the future-tense analog of a stale claim), orphan concepts with no inbound
links, concepts mentioned but not written, broken-link targets worth creating,
and type drift (synonyms / casing). No trigger fires the lint automatically — run
it periodically (e.g. when closing a fork, or before a release).

# Source discipline

Never edit files in `../references/`. The immutable sources are the ground truth;
this bundle is the curated, cross-linked reading of them.
