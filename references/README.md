# references/ — source-of-truth inputs, append-only

External inputs the project is built on: specs, standards, prior-art repos,
datasets, PDFs, and their text extracts. They are the ground truth that
`context/` synthesizes.

**Append-only, not read-only.** A directed ingest may *add* a new source here;
nothing already here is ever edited, reformatted, or deleted. Each snapshot is
immutable — the directory still grows.

- Put the raw source here (a PDF, a `.txt`, a vendored doc, a link file), exactly
  as it came. If it needs correcting or interpreting, that's a `context/` concept
  citing it, not an edit here.
- Cite it from `context/` concepts by name + section, not by extract line number
  (line numbers shift across revisions).
- Large binaries (PDFs, media) are good candidates for
  [git-lfs](https://git-lfs.com/) — track them in `.gitattributes`.

This README is a placeholder; keep it or delete it once real sources land.
