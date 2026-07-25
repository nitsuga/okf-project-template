# okf-project-template

A starter template for **agent-driven projects** that keeps project knowledge,
decisions, and plan in a small set of Markdown docs an AI agent maintains — and,
crucially, *instructions that tell the agent how to work* so those docs don't rot.

It's built on the
[OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
knowledge-catalog format (that's the `context/` bundle) and adds a
planning/decisions/working-hygiene layer around it. It is **not** an official OKF
artifact — OKF is one of the four parts.

## Quick Start

**1. Make your own copy.** On this repo's GitHub page, click **"Use this
template" → Create a new repository** (or
`gh repo create my-project --template <owner>/okf-project-template --private`).
Then clone your new repo locally.

**2. Customize it — let an agent walk you through it (recommended).** Open the new
project in your coding agent (e.g. Claude Code) and paste this:

> I just created this project from **okf-project-template** and it still has the
> template's placeholders. Please run the setup dialog in `SETUP.md`: ask me what
> you need to know, fill in the project's docs (name, scope, preferences, first
> tasks), and remove the example/placeholder content when we're done.

The agent runs a short Q&A, fills in the docs, deletes the example artifacts, and
removes the onboarding scaffolding — leaving a clean, customized project. Prefer
to do it by hand? Follow [Manual setup](#manual-setup) below instead.

**3. Start working.** Your project now has a knowledge bundle (`context/`), a
decision register (ADRs), a living plan (`planning/`), and agent working rules
(`CLAUDE.md`) — all wired together.

## The doc taxonomy

Four top-level doc directories, each with one job:

| Dir | Role | Audience |
|-----|------|----------|
| `references/` | **Immutable** source-of-truth inputs (specs, standards, prior art). Read, never modify. | inputs |
| `context/` | **Agent-owned** knowledge bundle (OKF): synthesized concepts + the decision register (ADRs). | agent |
| `planning/` | **Volatile** plan + present state — `ROADMAP.md` (scope/phases/open forks) and `PROGRESS.md` (Now/Next). | both |
| `docs/` | **Human-facing** authored guides (terse). | humans |

Plus [`CLAUDE.md`](CLAUDE.md) at the root — the *how-to-work* instructions an
agent auto-loads: the doc roles above, a pre-commit checklist, and the
planning-hygiene rules that keep the four from re-narrating each other. The
reasoning behind those rules — the failure mode each one prevents — is in
[`context/workflow-rationale.md`](context/workflow-rationale.md).

> **This section is the template's pitch, not project content.** Setup deletes it
> along with Quick Start and Manual setup: a set-up project's `README.md` is
> human-facing (what it is, how to build it, how it's laid out), and the workflow
> directives live where agents read them — `CLAUDE.md` and `context/`.

## Manual setup

The by-hand alternative to the agent dialog (Quick Start step 2) — the same
result, done yourself:

1. Copy/clone this tree into your new project (or use it as a GitHub template).
2. Fill in [`CLAUDE.md`](CLAUDE.md): the project description (top) and the
   **Project preferences** section (commit policy, repo layout, build/test/run).
3. **Rewrite this `README.md` as your project's own** — it should end up
   **human-facing**: what the project is, how to build and run it, how it's laid
   out, its license. Delete *all* of the template's pitch and adoption sections —
   title/intro, Quick Start, this Manual setup section, "The doc taxonomy", "Why
   these rules", and the template's Structure block. Don't carry the workflow
   directives into your README: they already live where agents read them
   (`CLAUDE.md` and [`context/`](context/workflow-rationale.md)), and a second
   copy in the README is exactly the duplication these rules exist to prevent.
   Keep Quick Start only if you want others to re-template from your repo.
4. Set the real `timestamp` in the frontmatter of `context/CONVENTIONS.md` and
   `context/workflow-rationale.md`; trim the `type` vocabulary to your domain.
5. Delete (or replace) the **example artifacts**, each marked with an
   `[EXAMPLE — replace or delete]` note:
   - `context/decisions/0001-example-decision.md` (a worked ADR)
   - the example entry in `context/log.md`
   - the example rows/sections in `context/index.md`,
     `context/decisions/index.md`, `planning/ROADMAP.md`, `planning/PROGRESS.md`
6. Decide on [`LICENSE`](LICENSE): the template ships **0BSD** (permissive, no
   attribution). Keep it for your project or swap in your own — and update the
   README license line (step 3) to match, so the two can't contradict each other.
7. Start working. On the first real decision, write ADR `0001`.

To find every spot that needs your attention (and confirm you got them all when
done), grep for the markers:
`grep -rnE '<PROJECT>|<[a-z][^>]*>|\[EXAMPLE|<!--' --include='*.md' .`

**That grep will not catch `README.md`.** This file has none of those markers, so
a README you skipped in step 3 passes it clean — leaving your project describing
*the template*, with a dead `SETUP.md` link and a possibly contradictory license
line. Check it separately:

```
head -1 README.md                                      # not "# okf-project-template"
grep -nE 'Use this template|SETUP\.md|Manual setup|0BSD' README.md
```

**Optional CI:** a GitHub Action that fails on broken internal doc links ships
**disabled**. Enable it any time with
`git mv .github/workflows/link-check.yml.disabled .github/workflows/link-check.yml`.

## Why these rules

The hygiene rules look fussy until you've watched docs rot. Each earned its place
by a failure mode: two docs narrating the same thing until one drifts; a status
doc accreting a "Done" pile; a prose tally ("19 tests", "forks 1–15") wrong the
moment the next change lands; a resolved item still listed under "Next"
somewhere; a doc updated "later" and therefore wrong in between. The meta-lesson:
**duplication rots — in both tenses.**

The rule-by-rule reasoning lives with the rules, in
[`context/workflow-rationale.md`](context/workflow-rationale.md) — read by an
agent before relaxing one, and carried into every project made from this
template.

## Structure

```
CLAUDE.md              how-to-work instructions (agent auto-loads)
SETUP.md               one-time setup dialog (agent-run; self-deletes after)
.github/workflows/
  link-check.yml.disabled   optional CI (rename to enable — fails on broken links)
context/               agent-owned OKF knowledge bundle
  index.md             bundle catalog (read first)
  CONVENTIONS.md       frontmatter, types, ADR format, ingest/query/lint
  workflow-rationale.md  why each planning-hygiene rule exists
  log.md               durable chronological record
  decisions/
    index.md           decided register: fork ↔ ADR ↔ status
    0001-*.md          ADRs (one example included)
planning/
  ROADMAP.md           scope, phases, open + candidate forks
  PROGRESS.md          present state: Now / In-progress / Next
references/            immutable inputs (read-only)
docs/                  human-facing guides
```

## License

[0BSD](LICENSE) (Zero-Clause BSD) — use, copy, and modify this template freely,
**no attribution required**. Projects you generate from it are yours to license
however you like (keep 0BSD or swap in your own `LICENSE`).
