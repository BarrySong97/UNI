# Module: reader-render-diff

## Module Purpose

Provides a developer-only offline EPUB audit harness for the Canvas reader.

The module now exposes two developer entrypoints:

1. `tool/reader_render_diff/run.mjs` for single-EPUB inspection
2. `tool/reader_render_diff/batch_structural_check.mjs` for multi-EPUB structural baselines

The single-book harness is no longer page-diff first. It now answers three narrower questions in order:

1. What content cases actually appear in this EPUB sample
2. Which browser-observed content objects were converted into `RenderNode` objects and which were missed
3. For high-confidence one-to-one matches only, what do browser HTML rendering and Flutter Canvas rendering look like side by side

## Boundary

### In
- Resolve EPUB input from `--epub`, `--sample`, or the default smoke sample in `./epubs`
- Discover `.epub` inputs from a target directory for batch structural checks
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
- Generate structural-only output:
  - `xhtml_inventory.json`
  - `structural_gaps.json`
- Generate aggregate structural-only output:
  - `batch_structural_report.json`
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

1. Resolve the target EPUB or EPUB directory plus output location.
2. Export Rust parser cache into the run-local `cache/` directory.
3. If the call is structural-only, stop after XHTML inventory plus structural gap comparison and write JSON artifacts.
4. Otherwise render the book in Chromium via `epub.js`.
5. Capture reference page screenshots, visible semantic block objects, and ignored-by-design special-case counts.
6. Run the Flutter harness test.
7. The Flutter harness loads cached chapter JSON, paginates with the existing reader pipeline, paints PNGs, and exports:
   - page screenshots
   - page-level visible block appearances
   - chapter-wide raw `RenderNode` inventory
8. Stage 1: build the canonical case inventory.
   - Browser objects are classified into block + inline/layout feature cases.
   - Canvas objects are classified from raw `RenderNode` inventory, not from screenshots.
9. Stage 2: find missing conversions.
   - Only browser-observed supported or partial cases are considered.
   - Ignored-by-design cases do not count as missing conversion.
   - Structural comparison skips list-item wrapper blocks such as `li > p` when the parser models them inside a parent `ListNode`.
   - Structural comparison also skips empty text-bearing elements unless they contain renderable non-text content such as inline images.
   - Missing cards show browser-only evidence.
10. Stage 3: build matched screenshot compare cards.
   - Matching is chapter-scoped and block-to-block only.
   - Only `exact` and `canonical_exact` one-to-one matches enter the main gallery.
   - Crops come from the first visible browser appearance and the first visible Canvas appearance of the same matched object.
11. Write JSON artifacts and `report.html`.
12. `report.html` uses single-column comparison cards so browser and Canvas crops stay large enough for manual review.
13. For directory runs, repeat the structural-only path per EPUB and aggregate parser failures plus ranked case hotspots into `build/reader_render_diff/_batch/batch_structural_report.json`.

## Key State & Data

- `tool/reader_render_diff/case_catalog.json`
- `tool/reader_render_diff/run.mjs`
- `tool/reader_render_diff/batch_structural_check.mjs`
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
- Batch report data:
  - `epubsScanned`
  - `epubsClean`
  - `epubsWithGaps`
  - `epubsWithParserErrors`
  - `byCaseId`
  - `prioritizedFixList`

## Interaction & Exceptions

- Missing `./epubs` or missing default smoke sample must fail clearly.
- Missing or empty batch directories must fail clearly.
- Sample hint matching must resolve to exactly one EPUB.
- Filenames with spaces and non-ASCII characters are supported.
- Smoke runs may cap chapters and pages; `--full-book` removes those caps.
- Batch runs must keep going after individual EPUB failures and record them as parser errors instead of aborting the whole job.
- Structural inventory skips non-markup spine resources so JSON or other fallback-only items do not crash the audit pipeline.
- Structural comparison includes nested parser-side lists stored under `ListItem.sub_nodes`, so table-of-contents style nested lists do not get reported as false missing elements.
- Structural comparison keeps empty-but-renderable structures such as empty tables and line-break-only paragraphs in the match set, preventing false over-converted reports.
- Structural inventory skips auxiliary `nav[epub:type~="landmarks"]` sections, so hidden guide navigation does not count as missing reader content.
- Browser and Canvas page counts may diverge heavily; the main report must not depend on equal pagination.
- The main HTML compare gallery only accepts high-confidence one-to-one matched content objects.
- Browser-only evidence is expected for unsupported, partial, or currently unconverted cases.
- Ignored-by-design categories stay visible in Case Inventory but do not count as missing conversion.
- Inline feature detection ignores empty formatting tags used only as spacing hacks, so structural checks do not report false italic/link gaps from zero-width or whitespace-only markup.

## Acceptance Criteria

- One local command can run against a real EPUB from `./epubs`.
- One local command can scan a directory tree of EPUBs and produce a ranked structural hotspot report.
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
