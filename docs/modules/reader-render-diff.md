# Module: reader-render-diff

## Module Purpose

Provides a developer-only offline harness that compares the current Canvas EPUB reader against a reference renderer based on `epub.js + Chromium`.

The module exists to help iterate the reader algorithm by producing repeatable screenshots, layout metrics, anchor-aligned diffs, and ranked reports for real EPUB samples under `./epubs`.

## Boundary

### In
- Resolve EPUB inputs from `--epub`, `--sample`, or the default smoke sample under `./epubs`
- Export chapter JSON from the Rust EPUB parser
- Render reference pages with `epub.js + Chromium`
- Render Canvas pages with the existing `RenderNode -> ReaderLayoutEngine -> ReaderCanvasPainter` pipeline
- Capture screenshots and structured per-page / per-anchor metrics
- Compare page-to-page output and anchor-aligned slices
- Apply manual allowlist rules for known unsupported differences
- Produce `report.json` and `report.html`

### Out
- End-user reader UI
- Real-time in-app debugging overlays
- CI gating in the first iteration
- Universal EPUB conformance claims
- Fully automatic classification of every unsupported EPUB/CSS feature

## Core Flow

1. Resolve the target EPUB:
   - `--epub /absolute/path/to/book.epub`
   - `--sample "<partial file name>"`
   - default smoke sample from `./epubs`
2. Create a run directory under `build/reader_render_diff/...`.
3. Export Rust parser output into a cache directory (`book.json`, `chapter_N.json`).
4. Launch Playwright + Chromium and render the EPUB with `epub.js`.
5. Capture reference screenshots and structured metrics per chapter/page.
6. Invoke the Flutter canvas harness test with a job JSON file.
7. The Flutter harness loads cached chapter JSON, paginates it with the existing reader pipeline, paints PNGs, and emits structured metrics.
8. Diff the two artifact sets in two modes:
   - page-to-page
   - anchor-aligned
9. Apply allowlist rules, score differences, and rank the most severe mismatches.
10. Write `report.json` and `report.html`.
11. `report.html` presents browser vs Canvas screenshots side-by-side and includes a human-readable problem summary beside each page comparison.

## Key State & Data

- `tool/reader_render_diff/run.mjs` CLI inputs
- `tool/reader_render_diff/allowlist.json`
- Run directory:
  - `input/`
  - `cache/`
  - `reference/`
  - `canvas/`
  - `diff/`
  - `report.json`
  - `report.html`
- Flutter harness job spec:
  - epub path
  - cache dir
  - output dir
  - viewport
  - device pixel ratio
  - chapter filter / limit
  - reader preferences
- Structured metrics:
  - page screenshot paths
  - normalized page text
  - block / image bounding boxes
  - style signatures
  - anchor records
- HTML report sections:
  - page comparison screenshots
  - per-page issue summary
  - anchor excerpt / mismatch context

## Interaction & Exceptions

- Missing `./epubs` or missing default smoke sample should fail with a clear error.
- Partial `--sample` matches must resolve to exactly one EPUB; zero or multiple matches are errors.
- Filenames with spaces or non-ASCII characters are supported.
- Reference and Canvas page counts can diverge; page-to-page diff remains informational.
- Anchor matching may be partial when pagination or unsupported styling diverges heavily.
- Allowlisted mismatches remain visible in reports but do not count toward hard failure.
- The harness is local-first and may depend on developer fonts and Chromium version.
- The HTML report should explain likely problems in prose instead of only exposing raw metrics.

## Acceptance Criteria

- One local command can run the harness against a real EPUB from `./epubs`.
- The default command uses the configured smoke sample when no input flags are provided.
- The harness produces both reference and Canvas screenshots.
- The harness emits page-level and anchor-level diagnostics.
- The report ranks the most severe mismatches and explains them beside the screenshots instead of only showing raw screenshot dumps.
- Known unsupported cases can be allowlisted without disappearing from the report.

## Non-Goals

- Shipping this harness to production users
- Treating reference output as a universal “correct” EPUB rendering
- Achieving zero visual diff in the first iteration
- Replacing focused unit tests for the layout engine
