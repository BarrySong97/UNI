# Module: reader-render-diff

## Module Purpose

Provides a developer-only offline EPUB audit harness for the Canvas reader.

The harness is no longer page-diff first. It now answers three narrower questions in order:

1. What content cases actually appear in this EPUB sample
2. Which browser-observed content objects were converted into `RenderNode` objects and which were missed
3. For high-confidence one-to-one matches only, what do browser HTML rendering and Flutter Canvas rendering look like side by side

## Boundary

### In
- Resolve EPUB input from `--epub`, `--sample`, or the default smoke sample in `./epubs`
- Export `book.json` and `chapter_N.json` through the Rust EPUB parser
- Render the same EPUB in `epub.js + Chromium`
- Reuse the real Canvas reader path:
  - `RenderNode`
  - `ReaderLayoutEngine`
  - `ReaderCanvasPainter`
- Build browser-side content-object inventory
- Build Canvas-side converted-node inventory directly from the `RenderNode[]` tree
- Generate three-stage report output:
  - Case Inventory
  - Missing Conversion
  - Matched Screenshot Compare
- Write developer artifacts:
  - `browser_objects.json`
  - `canvas_objects.json`
  - `case_inventory.json`
  - `missing_conversions.json`
  - `matched_comparisons.json`
  - `report.json`
  - `report.html`

### Out
- Production reader UI changes
- Automatic correctness judgment
- Page-to-page parity as the primary diagnostic model
- Weak fuzzy matching in the main report
- Auto-fixing parser or renderer logic

## Core Flow

1. Resolve the target EPUB and output directory.
2. Export Rust parser cache into the run-local `cache/` directory.
3. Render the book in Chromium via `epub.js`.
4. Capture reference page screenshots, visible semantic block objects, and ignored-by-design special-case counts.
5. Run the Flutter harness test.
6. The Flutter harness loads cached chapter JSON, paginates with the existing reader pipeline, paints PNGs, and exports:
   - page screenshots
   - page-level visible block appearances
   - chapter-wide raw `RenderNode` inventory
7. Stage 1: build the canonical case inventory.
   - Browser objects are classified into block + inline/layout feature cases.
   - Canvas objects are classified from raw `RenderNode` inventory, not from screenshots.
8. Stage 2: find missing conversions.
   - Only browser-observed supported or partial cases are considered.
   - Ignored-by-design cases do not count as missing conversion.
   - Missing cards show browser-only evidence.
9. Stage 3: build matched screenshot compare cards.
   - Matching is chapter-scoped and block-to-block only.
   - Only `exact` and `canonical_exact` one-to-one matches enter the main gallery.
   - Crops come from the first visible browser appearance and the first visible Canvas appearance of the same matched object.
10. Write JSON artifacts and `report.html`.
11. `report.html` uses single-column comparison cards so browser and Canvas crops stay large enough for manual review.

## Key State & Data

- `tool/reader_render_diff/case_catalog.json`
- `tool/reader_render_diff/run.mjs`
- Browser metrics:
  - page screenshots
  - semantic block captures
  - special ignored-case counts
- Canvas metrics:
  - page screenshots
  - page block appearances keyed by stable object ID
  - chapter node inventory derived from raw `RenderNode[]`
- Final report data:
  - `caseCatalog`
  - `caseInventory`
  - `browserObjects`
  - `canvasObjects`
  - `missingConversions`
  - `matchedComparisons`

## Interaction & Exceptions

- Missing `./epubs` or missing default smoke sample must fail clearly.
- Sample hint matching must resolve to exactly one EPUB.
- Filenames with spaces and non-ASCII characters are supported.
- Smoke runs may cap chapters and pages; `--full-book` removes those caps.
- Browser and Canvas page counts may diverge heavily; the main report must not depend on equal pagination.
- The main HTML compare gallery only accepts high-confidence one-to-one matched content objects.
- Browser-only evidence is expected for unsupported, partial, or currently unconverted cases.
- Ignored-by-design categories stay visible in Case Inventory but do not count as missing conversion.

## Acceptance Criteria

- One local command can run against a real EPUB from `./epubs`.
- The first report section is Case Inventory, not page diff.
- The harness shows browser-observed cases, converted-node coverage, and missing conversions.
- Missing conversion cards include browser evidence without fake Canvas placeholders.
- Matched screenshot compare only shows high-confidence one-to-one pairs.
- The Canvas export comes from the real reader pipeline, not duplicated layout code.

## Non-Goals

- Treating browser output as a universal source of truth
- Replacing targeted parser/layout tests
- Shipping this harness to end users
- Automatically deciding how reader logic should be changed after each run
