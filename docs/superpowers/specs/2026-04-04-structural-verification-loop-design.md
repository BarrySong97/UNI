# Structural Verification Loop for Reader Render Diff

## Problem

The current `reader-render-diff` harness uses epub.js + Chromium as the reference side. This reference has three reliability problems:

1. epub.js rendering has its own quirks, producing false positives/negatives in the diff
2. Flutter PictureRecorder headless screenshots may differ from real device output
3. Crop bounding rects can misalign, causing the matched pair to compare wrong content

These problems make the report unsuitable as an automated oracle for an AI Agent fix loop, because the AI cannot trust the comparison data.

## Insight

EPUB content correctness has two layers:

- **Structural correctness** (is the element present and correctly typed?) has an objective ground truth: the EPUB XHTML source file itself. A `<table>` in XHTML means there must be a TableNode in the RenderNode tree. This is deterministic and verifiable without any rendering engine.
- **Visual correctness** (does it look right?) has no single standard. This layer is deferred to human review.

The AI Agent fix loop targets structural correctness only. Ground truth comes from XHTML, not from epub.js.

## Architecture

```
Phase 0 (once per EPUB):
  EPUB XHTML files --> XHTML Inventory Parser --> xhtml_inventory.json

Phase 1 (each iteration):
  EPUB --> Rust parser --> chapter_N.json (RenderNode trees)

Phase 2 (each iteration):
  xhtml_inventory.json + chapter_N.json --> Structural Gap Detector --> structural_gaps.json

Phase 3 (each iteration):
  AI Agent reads structural_gaps.json --> fixes Rust/Dart code --> goto Phase 1
  Exit when structural_gaps.json shows 0 gaps
```

## Component 1: XHTML Inventory Parser

A new Node.js module at `tool/reader_render_diff/src/xhtml/build_xhtml_inventory.mjs`.

### Input

- Extracted EPUB XHTML chapter files (already available via the existing `extractEpubForReference` step, which unzips to `input/extracted/`)
- `case_catalog.json` (existing)

### What It Does

Parses each chapter XHTML file using a DOM parser (e.g., `linkedom` or `cheerio`), walks the DOM tree, and classifies every element against `case_catalog.json`. This replicates what the browser-side classifier does, but without rendering -- working directly on source XHTML.

For each block-level element encountered:

1. **Map tag to block case**: `<p>` -> `block.paragraph`, `<h1>` -> `block.heading.h1`, `<table>` -> `block.table.basic`, etc. Uses the same `sourceHtmlTags` mapping from `case_catalog.json`.
2. **Detect inline features**: Walk children for `<strong>` -> `inline.bold`, `<em>` -> `inline.italic`, `<a>` -> `inline.link`, etc.
3. **Detect layout features**: Parse inline `style=""` attributes and any `<style>` blocks in the XHTML for `text-align`, `margin`, `color`, `background-color`, etc. Map to `layout.*` cases.
4. **Detect special cases**: `<div>`, `<span>` etc. -> `special.flattened_container`; `<script>`, `<style>` -> `special.discarded_nonreading_content`; elements with `position: absolute|fixed` -> `special.out_of_flow_absolute_fixed`; elements with `display: none` -> `special.display_none`.
5. **Assign stable IDs**: Each element gets a deterministic ID based on chapter index + DOM path + content hash, so it can be tracked across iterations.
6. **Extract text content**: Normalized text for each block, used for cross-referencing with RenderNode output.

### Output

`xhtml_inventory.json`:

```json
{
  "epubPath": "epubs/sample.epub",
  "chapters": [
    {
      "chapterIndex": 0,
      "xhtmlPath": "chapter1.xhtml",
      "elements": [
        {
          "elementId": "ch0_p_0_a1b2c3",
          "domPath": "body > div > p:nth-child(1)",
          "tagName": "p",
          "blockCaseId": "block.paragraph",
          "featureCaseIds": ["inline.bold", "inline.link"],
          "layoutCaseIds": ["layout.align.left", "layout.margin"],
          "normalizedText": "some bold text with a link",
          "status": "supported"
        }
      ],
      "specialCaseCounts": {
        "special.flattened_container": 5,
        "special.discarded_nonreading_content": 2
      }
    }
  ],
  "summary": {
    "totalElements": 42,
    "byCaseId": {
      "block.paragraph": 20,
      "block.heading.h1": 1,
      "inline.bold": 8
    }
  }
}
```

### CSS Handling

Full CSS cascade is complex. For the first version, handle only:

1. Inline `style=""` attributes (highest specificity, most common in EPUBs)
2. Element-level defaults (`<center>` -> text-align: center, `<blockquote>` -> margin-left)

External stylesheets and `<style>` blocks are deferred to a future iteration. This is acceptable because the structural question "does this element exist?" does not depend on CSS. Layout case detection (`layout.*`) may be incomplete without full CSS, but block and inline cases will be accurate.

## Component 2: Structural Gap Detector

A new Node.js module at `tool/reader_render_diff/src/xhtml/find_structural_gaps.mjs`.

### Input

- `xhtml_inventory.json` (from Component 1)
- `cache/chapter_N.json` (from Rust parser, existing)
- `case_catalog.json` (existing)

### What It Does

For each chapter, walks the Rust parser's RenderNode tree and builds a canvas-side inventory (reusing existing `RenderDiffNodeInventory` classification logic or its JS equivalent). Then compares:

1. **Element-level matching**: For each XHTML element, find a corresponding RenderNode by:
   - Same chapter
   - Same block case (or compatible: e.g., `<dt>` -> ParagraphNode is expected)
   - For text-bearing elements: normalized text equality
   - For non-text elements (`<hr>`, `<img>`): tag type + DOM order position + image alt/src signature
   - DOM order proximity as tiebreaker when multiple candidates match

2. **Gap detection**: An XHTML element is a "structural gap" if:
   - Its `blockCaseId` status is `supported` or `partial` in `case_catalog.json`
   - No matching RenderNode was found
   - It is not a `special.*` case (those are expected to have no RenderNode)

3. **Feature gap detection**: Even if a block matches, check inline/layout features:
   - XHTML has `<strong>` child but matched RenderNode's Text children lack `bold: true` -> feature gap
   - XHTML has `text-align: center` but RenderNode has `align: Left` -> feature gap

4. **Over-conversion detection**: RenderNodes that have no matching XHTML element. These indicate parser bugs where content is fabricated.

### Output

`structural_gaps.json`:

```json
{
  "summary": {
    "totalXhtmlElements": 42,
    "matchedElements": 38,
    "missingElements": 3,
    "featureGaps": 5,
    "overConvertedNodes": 1,
    "gapScore": 16
  },
  "gaps": [
    {
      "type": "missing_element",
      "chapterIndex": 0,
      "elementId": "ch0_table_0_d4e5f6",
      "domPath": "body > div > table:nth-child(5)",
      "blockCaseId": "block.table.basic",
      "normalizedText": "header row 1 data cell ...",
      "status": "supported",
      "hint": "Rust parser does not handle <table> in this context. Check html.rs walk_children_of_node() for table handling."
    },
    {
      "type": "feature_gap",
      "chapterIndex": 0,
      "elementId": "ch0_p_3_g7h8i9",
      "blockCaseId": "block.paragraph",
      "matchedNodeKind": "ParagraphNode",
      "missingFeature": "inline.superscript",
      "detail": "XHTML contains <sup> child but RenderNode Text children lack superscript=true",
      "hint": "Check html.rs walk_inline_children() for <sup> tag handling."
    },
    {
      "type": "over_converted",
      "chapterIndex": 1,
      "renderNodeKind": "ParagraphNode",
      "normalizedText": "",
      "hint": "Empty ParagraphNode with no matching XHTML source. Likely generated from whitespace or flattened container."
    }
  ]
}
```

### Actionable Hints

Each gap includes a `hint` field pointing the AI Agent to the likely fix location:

- `missing_element` with tag `<table>` -> "Check html.rs table handling"
- `missing_element` with tag `<blockquote>` -> "Check html.rs blockquote handling"
- `feature_gap` with `inline.bold` -> "Check html.rs walk_inline_children() for `<strong>`/`<b>` tags"
- `feature_gap` with `layout.align.center` -> "Check html.rs StyleProps text_align extraction"
- `over_converted` -> "Check html.rs for spurious node generation from whitespace/containers"

## Component 3: AI Agent Fix Loop Runner

A new CLI mode at `tool/reader_render_diff/run.mjs --auto-fix-loop`.

### Flow

```
1. Resolve EPUB, create output directory
2. Extract EPUB to input/extracted/
3. Run XHTML Inventory Parser -> xhtml_inventory.json  (once, cached)
4. Loop:
   a. Run Rust parser: cargo run -- <epub> --batch-export <cache>
   b. Run Structural Gap Detector: xhtml_inventory + chapter JSONs -> structural_gaps.json
   c. Print summary: "Iteration N: 3 missing, 5 feature gaps, gapScore=16"
   d. If gapScore == 0: print "All structural gaps resolved." and exit
   e. Write structural_gaps.json to output directory
   f. Exit with code 1 (signal to AI Agent: "gaps remain, fix and re-run")
```

The loop itself is NOT in `run.mjs`. The AI Agent is the outer loop:

```
AI Agent:
  1. Run: node run.mjs --structural-check --epub <path>
  2. Read structural_gaps.json
  3. Pick highest-priority gap (missing_element before feature_gap)
  4. Read hint, navigate to Rust/Dart source, make fix
  5. Re-run step 1
  6. If gapScore decreased: continue
  7. If gapScore increased or unchanged: revert, try different fix
  8. Repeat until gapScore == 0
```

### CLI Interface

```bash
# Full existing report (unchanged)
node tool/reader_render_diff/run.mjs --epub epubs/sample.epub

# New: structural check only (fast, no Chromium, no Flutter)
node tool/reader_render_diff/run.mjs --structural-check --epub epubs/sample.epub

# New: structural check with specific chapters
node tool/reader_render_diff/run.mjs --structural-check --epub epubs/sample.epub --max-chapters 3
```

`--structural-check` skips all browser rendering, Flutter harness, screenshot capture, and visual matching. It only runs:
1. EPUB extraction
2. XHTML inventory
3. Rust parser
4. Structural gap detection

Expected runtime: seconds, not minutes.

## Integration with Existing Harness

The new components coexist with the existing report flow. Existing report logic is unchanged; only `run.mjs` gains a new `--structural-check` code path.

```
tool/reader_render_diff/
  run.mjs                          (existing, add --structural-check flag)
  case_catalog.json                (existing, unchanged)
  src/
    xhtml/
      build_xhtml_inventory.mjs    (NEW)
      find_structural_gaps.mjs     (NEW)
      parse_xhtml_dom.mjs          (NEW - DOM parsing utility)
    reference/                     (existing, unchanged)
    cases/                         (existing, unchanged)
    audit/                         (existing, unchanged)
    report/                        (existing, unchanged)
```

## Dependencies

- `linkedom` (npm) -- lightweight DOM parser for XHTML. No browser needed. Already used in similar Node.js tooling. Alternative: `cheerio` if HTML5 tolerance is preferred, but `linkedom` is closer to spec-compliant XML parsing which suits EPUB XHTML.

## Scope Limits

- CSS cascade from external stylesheets is NOT implemented in v1. Only inline `style=""` and element-level defaults.
- Visual correctness is NOT verified. The AI Agent loop is structural only.
- The existing full report (`run.mjs` without `--structural-check`) is unchanged and remains available for human visual review after the structural loop completes.
- The AI Agent orchestration (how it reads gaps, decides what to fix, reverts bad changes) is outside this spec. This spec provides the tools the agent needs: `xhtml_inventory.json` and `structural_gaps.json`.

## Success Criteria

1. `node run.mjs --structural-check --epub <path>` completes in under 10 seconds for a typical EPUB
2. `xhtml_inventory.json` correctly identifies all block and inline elements in test EPUBs
3. `structural_gaps.json` correctly identifies known missing conversions (cross-check against existing `missing_conversions.json` from full report)
4. Running the structural check after fixing a known parser gap shows the gap disappearing from `structural_gaps.json`
5. The `gapScore` metric (`missingElements * 3 + featureGaps * 1 + overConvertedNodes * 2`, weighted by severity) monotonically tracks structural completeness -- AI Agent can use it as a single number to optimize toward 0

## Test Plan

1. Run `--structural-check` on each of the 6 test EPUBs in `./epubs`
2. Compare `xhtml_inventory.json` element counts against manual inspection of XHTML source for at least one chapter
3. Compare `structural_gaps.json` against existing `missing_conversions.json` from a full report run -- structural gaps should be a superset (since XHTML ground truth may find gaps that epub.js missed)
4. Manually introduce a parser bug (e.g., comment out `<blockquote>` handling in `html.rs`), verify the structural gap appears
5. Fix the bug, verify the gap disappears
