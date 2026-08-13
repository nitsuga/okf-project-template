#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 - "$SCRIPT_DIR" "$@" <<'PY'
#!/usr/bin/env python3
"""Canonical lint for the OKF docs bundle (context/, planning/).

One command, no dependencies. Runs the checks that keep the docs from drifting,
so `AGENTS.md` § Planning hygiene has teeth locally and the CI is just this script:

    ./scripts/lint.sh            # check the whole repo (warnings don't fail)
    ./scripts/lint.sh --strict   # optional: treat warnings as failures too

Severity:
  FAIL  integrity + conformance + lifecycle -- must fix.
  WARN  heuristics (tallies, orphans, type drift, stale_after, ...) -- investigate.
  NOTE  informational.

Template state: a repo is an un-customized template only when `SETUP.md` is
present AND the README still advertises the template AND `AGENTS.md` still has
its "First run" onboarding section. While in that state the setup markers are
summarized as a NOTE instead of failing. Any partial state (e.g. `SETUP.md`
left behind after customizing) is enforced: unambiguous markers (`<PROJECT>`,
`[EXAMPLE`, sentinel `2000-01-01`) fail; ambiguous ones that also match ordinary
Markdown (autolinks like `<https://...>`, `<!--` comments) only warn.

This file is the single source of truth for the checks. `context/CONVENTIONS.md`
§ Operations points at it rather than re-enumerating the rules, so prose and
code can't drift apart. Keep any rule you add here in sync with that pointer,
not with a second description.
"""

import os
import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve().parent
STRICT = "--strict" in sys.argv

FAILS: list[str] = []
WARNS: list[str] = []
NOTES: list[str] = []


def fail(msg: str) -> None:
    FAILS.append(msg)


def warn(msg: str) -> None:
    WARNS.append(msg)


def note(msg: str) -> None:
    NOTES.append(msg)


def rel(p: Path) -> str:
    try:
        return str(p.relative_to(ROOT))
    except ValueError:
        return str(p)


# ---------------------------------------------------------------- discovery

md_files = sorted(
    p
    for p in ROOT.glob("**/*.md")
    if not any(part.startswith(".") for part in p.relative_to(ROOT).parts)
)

FM_RE = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)

# Concept files: markdown under context/, excluding the reserved index.md/log.md.
concept_files = [
    p
    for p in md_files
    if "context" in p.relative_to(ROOT).parts and p.name not in {"index.md", "log.md"}
]

adr_files = sorted(
    p
    for p in (ROOT / "context" / "decisions").glob("*.md")
    if p.name != "index.md"
)

concept_slugs = {p.stem for p in ROOT.glob("context/**/*.md")}

DECIDED_STATUSES = {"accepted", "superseded", "deferred"}
DECISION_STATUSES = DECIDED_STATUSES | {"proposed"}


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def frontmatter_block(path: Path):
    m = FM_RE.match(read(path))
    return (m.group(1), read(path)) if m else (None, read(path))


def field(block: str | None, name: str) -> str | None:
    """Top-level scalar frontmatter field (line starts with `name:`)."""
    if block is None:
        return None
    m = re.search(r"^" + re.escape(name) + r":\s*(.+?)\s*$", block, re.M)
    return m.group(1) if m else None


def nested_field(block: str | None, name: str) -> list[str]:
    """Indented `name:` values (e.g. `by:`/`at:` under `generated:`)."""
    if block is None:
        return []
    return re.findall(r"^\s+" + re.escape(name) + r":\s*(.+?)\s*$", block, re.M)


def source_ids(block: str | None) -> set[str]:
    if block is None:
        return set()
    return set(re.findall(r"^\s*-?\s*id:\s*(\S+)", block, re.M))


def top_level_keys(block: str | None) -> set[str]:
    if block is None:
        return set()
    return set(re.findall(r"^([\w.-]+):", block, re.M))


def type_vocabulary() -> set[str] | None:
    """Recognized concept types, parsed from CONVENTIONS.md's type table.

    The table is the single source of truth — README step 4 / SETUP.md tell an
    adopter to trim it to their domain, so this reads it rather than keeping a
    second copy here. Returns None when the table can't be found, and the caller
    then skips the check rather than false-warning on every concept.
    """
    p = ROOT / "context" / "CONVENTIONS.md"
    if not p.exists():
        return None
    m = re.search(r"\| Type \| Use for \|.*?(?=\n\n|\Z)", read(p), re.DOTALL)
    if not m:
        return None
    vocab = set(re.findall(r"^\|\s*`([^`]+)`\s*\|", m.group(0), re.M))
    vocab.add("Attested Computation")  # OKF-spec type, declared in prose not the table
    return vocab


# --------------------------------------------------------- 1. link integrity

referenced_paths: set[str] = set()
referenced_slugs: set[str] = set()
n_rel_links = 0
n_wikilinks = 0


def check_links(path: Path) -> None:
    global n_rel_links, n_wikilinks
    raw = read(path)
    fm = FM_RE.match(raw)
    ids = source_ids(fm.group(1)) if fm else set()
    text = raw
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)   # fenced code
    text = re.sub(r"`[^`]*`", "", text)                      # inline code
    text = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)  # HTML comments
    base = path.parent
    for m in re.findall(r"\]\(([^)]+)\)", text):
        t = m.split("#")[0].strip()
        if not t or t.startswith(("http://", "https://", "mailto:")):
            continue
        if t.startswith("/"):
            fail(f"ROOT-ABSOLUTE  {rel(path)}  ->  {m}  (use a ./relative path)")
            continue
        target = (base / t)
        if target.exists():
            referenced_paths.add(os.path.normpath(str(target.resolve())))
            n_rel_links += 1
        else:
            fail(f"BROKEN LINK  {rel(path)}  ->  {m}")
    for w in re.findall(r"\[\[([^\]]+)\]\]", text):
        slug = w.split("|")[0].split("#")[0].strip()
        referenced_slugs.add(slug)
        n_wikilinks += 1
        if slug not in concept_slugs:
            fail(f"BROKEN WIKILINK  {rel(path)}  ->  [[{w}]]")
    for lab in set(re.findall(r"\[\^([^\]]+)\]", text)):
        if lab not in ids:
            fail(f"DANGLING FOOTNOTE  {rel(path)}  ->  [^{lab}]  (no matching sources[].id)")


for f in md_files:
    check_links(f)

if n_rel_links and n_wikilinks:
    warn(
        f"mixed link forms: {n_wikilinks} [[wikilink]] and {n_rel_links} "
        "./relative link(s) in one bundle — pick one form (CONVENTIONS § Linking)"
    )

# --------------------------------------------- 2. bundle shape / conformance

vocab = type_vocabulary()

for p in concept_files:
    block, _ = frontmatter_block(p)
    if block is None:
        fail(f"{rel(p)}: concept has no frontmatter (requires a `type` field)")
        continue
    t = field(block, "type")
    if not t:
        fail(f"{rel(p)}: frontmatter missing required `type`")
        continue
    if vocab is not None and t not in vocab:
        warn(
            f'{rel(p)}: unrecognized type "{t}" — emerging type? add it to the '
            "CONVENTIONS type vocabulary"
        )

root_index = ROOT / "context" / "index.md"
if root_index.exists():
    block, _ = frontmatter_block(root_index)
    bad = top_level_keys(block) - {"okf_version"}
    if bad:
        fail(
            f"{rel(root_index)}: reserved index.md may only carry `okf_version` "
            f"(found {sorted(bad)})"
        )

for p in ROOT.glob("context/**/index.md"):
    if p == root_index:
        continue
    block, _ = frontmatter_block(p)
    if block is not None:
        fail(f"{rel(p)}: reserved index.md must not have frontmatter")

for p in ROOT.glob("context/**/log.md"):
    block, _ = frontmatter_block(p)
    if block is not None:
        fail(f"{rel(p)}: reserved log.md must not have frontmatter")

log_file = ROOT / "context" / "log.md"
if log_file.exists():
    for line in read(log_file).splitlines():
        if line.startswith("## "):
            h = line[3:].strip()
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", h):
                warn(f'{rel(log_file)}: non-date heading "## {h}" (log.md headings are ISO YYYY-MM-DD)')

# ------------------------------------------------------------- ADR lifecycle

adr_nums: list[int] = []
adr_status: dict[str, str] = {}


def check_adr_files() -> None:
    for p in adr_files:
        block, raw = frontmatter_block(p)
        if not re.fullmatch(r"\d{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md", p.name):
            fail(f'{rel(p)}: ADR filename must be NNNN-slug.md (got "{p.name}")')
            continue
        adr_nums.append(int(p.name[:4]))
        ds = field(block, "decision_status")
        adr_status[str(p.resolve())] = ds or ""
        if ds not in DECISION_STATUSES:
            fail(f'{rel(p)}: decision_status "{ds}" not in {sorted(DECISION_STATUSES)}')
            continue
        if ds == "superseded":
            body = raw.split("---", 2)[-1]
            if not re.search(r"\d{4}-[a-z0-9-]+\.md", body):
                warn(f"{rel(p)}: superseded ADR does not link a superseder (NNNN-slug.md)")


def parse_register() -> list[dict]:
    p = ROOT / "context" / "decisions" / "index.md"
    rows: list[dict] = []
    if not p.exists():
        return rows
    for line in read(p).splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if len(cells) < 3:
            continue
        fork_cell, adr_cell, status = cells[0], cells[1], cells[2]
        if fork_cell in ("Fork", "") or re.fullmatch(r":?-{2,}:?", fork_cell):
            continue
        m = re.search(r"\]\(([^)]+)\)", adr_cell)
        if not m:
            warn(f'{rel(p)}: register row "{fork_cell}" has no ADR link')
            continue
        rows.append({"fork": fork_cell, "link": m.group(1), "status": status})
    return rows


check_adr_files()

for num, count in Counter(adr_nums).items():
    if count > 1:
        fail(f"duplicate ADR number {num:04d}")

register = parse_register()
registered_adr_paths: set[str] = set()
register_fork_nums: set[int] = set()
for row in register:
    target = (ROOT / "context" / "decisions" / row["link"]).resolve()
    if not target.exists():
        fail(f'register references missing ADR: {row["link"]}')
        continue
    ap = os.path.normpath(str(target))
    registered_adr_paths.add(ap)
    if row["status"] not in DECIDED_STATUSES:
        fail(
            f'register row fork {row["fork"]}: status "{row["status"]}" is not a '
            f"decided status ({sorted(DECIDED_STATUSES)})"
        )
    if re.fullmatch(r"\d+", row["fork"]):
        register_fork_nums.add(int(row["fork"]))
    if ap in adr_status and adr_status[ap] != row["status"]:
        warn(
            f'register row fork {row["fork"]}: status "{row["status"]}" != ADR '
            f'decision_status "{adr_status[ap]}"'
        )

for p in adr_files:
    ds = adr_status.get(str(p.resolve()), "")
    if ds in DECIDED_STATUSES and str(p.resolve()) not in registered_adr_paths:
        fail(f"{rel(p)}: decided ({ds}) but missing from the register (decisions/index.md)")
    if ds == "proposed" and str(p.resolve()) in registered_adr_paths:
        fail(
            f'{rel(p)}: decision_status is "proposed" but it has a register row '
            "(the register holds only decided forks)"
        )

# stale-forward cross-check: ROADMAP "Open forks" still referencing a decided ADR
roadmap = ROOT / "planning" / "ROADMAP.md"
if roadmap.exists():
    text = read(roadmap)
    m = re.search(r"## Open forks(.*?)(?=\n## |\Z)", text, re.DOTALL)
    if m:
        section = m.group(1)
        for link in re.findall(r"\]\(([^)]+)\)", section):
            t = link.split("#")[0].strip()
            resolved = (roadmap.parent / t).resolve()
            if os.path.normpath(str(resolved)) in registered_adr_paths:
                fail(f'ROADMAP "Open forks" still links a decided ADR: {link} (scrub it on close)')
        for num in re.findall(r"[Ff]ork\s*#?\s*(\d+)", section):
            if int(num) in register_fork_nums:
                fail(f'ROADMAP "Open forks" still lists decided fork #{num} (scrub it on close)')

# ----------------------------------------------------- 4. setup completeness

def scan_setup_markers():
    # Unambiguous template leftovers — fail once setup has begun.
    fail_pats = [
        (re.compile(r"<PROJECT>"), "<PROJECT> placeholder"),
        (re.compile(r"\[EXAMPLE"), "EXAMPLE artifact"),
        (re.compile(r"2000-01-01"), "sentinel date 2000-01-01"),
    ]
    # Ambiguous — also match ordinary Markdown (autolinks, generics, TODO
    # comments), so they are advisory and never a build failure.
    warn_pats = [
        (re.compile(r"<[a-z][^>]*>"), "placeholder <...>"),
        (re.compile(r"<!--"), "guidance comment (<!--)"),
    ]
    fails: list[tuple] = []
    warns: list[tuple] = []
    for p in md_files:
        text = read(p)
        text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
        text = re.sub(r"`[^`]*`", "", text)
        for rx, label in fail_pats:
            for m in rx.finditer(text):
                fails.append((p, label, m.group(0)))
        for rx, label in warn_pats:
            for m in rx.finditer(text):
                warns.append((p, label, m.group(0)))
    return fails, warns


def show(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


setup_present = (ROOT / "SETUP.md").exists()

agents = ROOT / "AGENTS.md"
first_run = False
if agents.exists():
    first_run = bool(re.search(r"^##\s+First run\b", read(agents), re.M))

claude = ROOT / "CLAUDE.md"
claude_ok = True
if claude.exists():
    lines = [l for l in read(claude).splitlines() if l.strip()]
    claude_ok = bool(lines) and lines[0].strip() == "@AGENTS.md"

# A README never rewritten for setup still advertises the template. Check the
# title plus the adoption sections README/SETUP document as the telltales.
readme_template = False
readme = ROOT / "README.md"
if readme.exists():
    text = read(readme)
    readme_template = (
        text.splitlines()[0].strip() == "# okf-project-template"
        or bool(re.search(r"Use this template|Manual setup|doc taxonomy|Why these rules", text))
    )

# Fully un-customized: all three onboarding signals still agree. Anything less
# is a partial setup (e.g. finished customizing but forgot to delete SETUP.md),
# which must be enforced rather than reported clean.
template_state = setup_present and readme_template and first_run

marker_fails, marker_warns = scan_setup_markers()

fail_leftovers: list[str] = []
if first_run:
    fail_leftovers.append('"First run" section still in AGENTS.md')
if not claude_ok:
    fail_leftovers.append("CLAUDE.md does not start with @AGENTS.md")
if readme_template:
    fail_leftovers.append("README.md still advertises the template")
if setup_present:
    fail_leftovers.append("SETUP.md still present")
fail_leftovers += [f"{rel(p)}: {label} ({show(m)!r})" for p, label, m in marker_fails]
warn_leftovers = [f"{rel(p)}: {label} ({show(m)!r})" for p, label, m in marker_warns]

if template_state:
    n = len(marker_fails) + len(marker_warns)
    note(
        f"template not yet customized (SETUP.md present): {n} setup marker(s); "
        "unambiguous ones become failures, ambiguous ones warnings, once setup completes"
    )
else:
    for it in fail_leftovers:
        fail(f"setup leftover: {it}")
    for it in warn_leftovers:
        warn(f"possible setup leftover (advisory): {it}")

# ------------------------------------------------- 5. soft heuristics (warn)

def prose_text(p: Path) -> str:
    block, raw = frontmatter_block(p)
    text = raw if block is None else FM_RE.sub("", raw, count=1)
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"`[^`]*`", "", text)
    return text


tally_pat = re.compile(
    r"\b\d+\s+of\s+\d+\b|\b(?:forks?|tests?|concepts?|items?|docs?)\s*\d+\s*[-–—]\s*\d+\b",
    re.I,
)
for p in [ROOT / "planning" / "PROGRESS.md", ROOT / "planning" / "ROADMAP.md"] + adr_files:
    if not p.exists():
        continue
    for m in tally_pat.finditer(prose_text(p)):
        warn(f'{rel(p)}: possible live tally "{m.group(0)}" (describe the state, not a count)')

for p in concept_files:
    ap = os.path.normpath(str(p.resolve()))
    if ap not in referenced_paths and p.stem not in referenced_slugs:
        warn(f"{rel(p)}: orphan concept — no inbound link from any doc")

today = date.today()
for p in concept_files:
    block, _ = frontmatter_block(p)
    sa = field(block, "stale_after")
    if not sa:
        continue
    m = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", sa)
    if not m:
        warn(f'{rel(p)}: stale_after "{sa}" not YYYY-MM-DD')
        continue
    d = date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    if d < today:
        warn(f"{rel(p)}: stale_after {sa} is in the past")

for p in concept_files:
    block, _ = frontmatter_block(p)
    for by in nested_field(block, "by"):
        if by == "<actor>":
            continue  # placeholder, caught by setup markers
        if not (
            by.startswith("human:")
            or by.startswith("process:")
            or re.fullmatch(r"[^\s/]+/[^\s/]+", by)
        ):
            warn(
                f'{rel(p)}: actor "{by}" does not match human:<id>, process:<id>, '
                "or <producer>/<version>"
            )

# ------------------------------------------------------------------ report

def report(header: str, items: list[str]) -> None:
    if not items:
        return
    print(f"\n{header} ({len(items)})")
    for it in items:
        print(f"  - {it}")


report("FAIL", FAILS)
report("WARN", WARNS)
report("NOTE", NOTES)

n_fail = len(FAILS) + (len(WARNS) if STRICT else 0)
if FAILS or (STRICT and WARNS):
    print(f"\nlint: {n_fail} problem(s), {len(WARNS)} warning(s)")
    sys.exit(1)
print(f"\nlint clean ({len(WARNS)} warning(s), {len(NOTES)} note(s))")
sys.exit(0)
PY
