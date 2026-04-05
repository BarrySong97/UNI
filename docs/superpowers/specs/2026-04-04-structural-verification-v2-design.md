# Structural Verification V2: Test Suite + AI Fix Loop

## Background

V1 of the structural verification tool (`--structural-check`) is complete and functional. It compares EPUB XHTML source against Rust parser output and reports structural gaps.

**Problem with V1**: The 6 test EPUBs in `./epubs` are structurally simple. The parser already handles them correctly, so `--structural-check` reports 0 gaps. The tool works, but there are no targets to shoot at.

**This spec** adds real test ammunition (EPUB test suites + complex real books), a batch runner to find all gaps at once, and defines how an AI Agent uses the results to fix the parser in a loop.

## What Already Exists (V1, unchanged)

- `tool/reader_render_diff/src/xhtml/build_xhtml_inventory.mjs` — parses EPUB XHTML, classifies elements against `case_catalog.json`
- `tool/reader_render_diff/src/xhtml/find_structural_gaps.mjs` — compares XHTML inventory vs Rust parser RenderNode output
- `node run.mjs --structural-check --epub <path>` — runs both in seconds, outputs `xhtml_inventory.json` + `structural_gaps.json`
- `case_catalog.json` — 57 cases across block/inline/layout/special layers

## Step 1: Acquire Test EPUBs

### 1a. IDPF EPUB 3 Samples (realistic books)

Download pre-built EPUBs from https://github.com/IDPF/epub3-samples/releases/tag/20230704

Priority samples (cover features the current 6 books lack):

| Sample | Key features to stress-test |
|--------|-----------------------------|
| `accessible_epub_3` | Semantic HTML5 (`<figure>`, `<figcaption>`, `<aside>`, `<section>`) |
| `linear-algebra` | MathML, complex tables with colspan/rowspan |
| `kusamakura-japanese-vertical-writing` | Ruby annotations (`<ruby>`, `<rt>`), vertical writing mode |
| `wasteland-otf` | OTF font embedding, poetry line formatting |
| `cole-voyage-of-life-tol` | SVG in spine, image-heavy |
| `childrens-media-query` | CSS media queries, responsive layout |
| `indexing-for-eds-and-auths-3f` | Index markup, nested definition lists |
| `regime-anticancer-arabic` | RTL text, Arabic script |
| `figure-gallery-bindings` | `<figure>` + `<figcaption>` combinations |
| `moby-dick-mo` | Large book (136 chapters), media overlays, footnotes |

Store in: `epubs/idpf-samples/`

### 1b. W3C EPUB 3 Conformance Tests (spec compliance)

Clone and build from https://github.com/w3c/epub-tests

```bash
git clone https://github.com/w3c/epub-tests.git /tmp/epub-tests
cd /tmp/epub-tests/tests && bash generateEpubs.sh
```

204 individual tiny EPUBs, each testing one specific spec requirement. Relevant subsets for structural testing:

| Prefix | Count | Relevance |
|--------|-------|-----------|
| `cnt-` | 11 | Content documents: SVG, fonts, MathML, XHTML support |
| `css-` | 10 | EPUB CSS: hyphens, line-break, text-emphasis, writing-mode |
| `pub-` | 24 | Content media types, external links, data URLs |

The remaining tests (layout, media overlays, scripting, navigation, security) test reading system behavior not parser structure — skip them for structural verification.

Store in: `epubs/w3c-tests/`

### 1c. Complex Real Books (already downloaded)

Currently in `./epubs/`:

| Book | Key features |
|------|-------------|
| A Brief History of Time | Tables, footnotes, index |
| HTML & CSS (Duckett) | Code blocks, heavy image+text mixing, complex layout |
| Salt, Fat, Acid, Heat | Recipe tables, image sizing, lists |
| Sapiens | Footnotes, nested blockquotes, chapter structure |
| コンビニ人間 | Japanese text (potential ruby) |

**Note**: The Rust Programming Language was downloaded as PDF, not EPUB. Step 1 of the implementation plan will download the official EPUB from `https://doc.rust-lang.org/book/book.epub` and remove the PDF.

### Directory Structure

```
epubs/
  # Existing simple books (keep as regression baseline)
  Common Goal...epub
  Heart the Lover...epub
  ...

  idpf-samples/          # NEW: realistic sample books
    accessible_epub_3.epub
    linear-algebra.epub
    kusamakura-japanese-vertical-writing.epub
    ...

  w3c-tests/             # NEW: conformance test EPUBs
    cnt-svg-support.epub
    css-writing-mode.epub
    ...

  # Complex real books (already here, keep in place)
  A Brief History of Time...epub
  Salt, Fat, Acid, Heat...epub
  ...
```

## Step 2: Batch Runner

A new script `tool/reader_render_diff/batch_structural_check.mjs` that runs `--structural-check` on all EPUBs and produces a single aggregate report.

### CLI

```bash
# Run on all EPUBs in a directory
node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/

# Run on a specific subset
node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/idpf-samples/

# Run on all directories
node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/ --recursive
```

### What It Does

1. Glob all `.epub` files in the target directory (optionally recursive)
2. For each EPUB:
   a. Call the existing `--structural-check` pipeline (extract → XHTML inventory → Rust parser → gap detection)
   b. Collect `structural_gaps.json` result
   c. If the Rust parser crashes or fails to parse (some EPUBs may use features it cannot handle), catch the error and record as `parser_error`
3. Aggregate into `batch_structural_report.json`

### Output

`build/reader_render_diff/batch_structural_report.json`:

```json
{
  "generatedAt": "2026-04-04T12:00:00Z",
  "epubsScanned": 25,
  "epubsWithGaps": 8,
  "epubsWithParserErrors": 2,
  "totalGapScore": 147,
  "summary": {
    "missingElements": 45,
    "featureGaps": 32,
    "overConvertedNodes": 12
  },
  "byCaseId": {
    "block.table.colspan": { "missing": 12, "epubs": ["linear-algebra", "salt-fat-acid-heat"] },
    "inline.superscript": { "featureGap": 8, "epubs": ["sapiens", "brief-history-of-time"] },
    "block.image": { "missing": 5, "epubs": ["cole-voyage-of-life-tol"] }
  },
  "byEpub": [
    {
      "epub": "epubs/idpf-samples/linear-algebra.epub",
      "slug": "linear-algebra",
      "status": "gaps_found",
      "gapScore": 34,
      "missingElements": 15,
      "featureGaps": 8,
      "overConvertedNodes": 2,
      "topGaps": ["block.table.colspan", "block.table.rowspan", "inline.superscript"]
    },
    {
      "epub": "epubs/idpf-samples/kusamakura-japanese-vertical-writing.epub",
      "slug": "kusamakura",
      "status": "parser_error",
      "error": "thread 'main' panicked at 'unknown element: ruby'"
    }
  ],
  "prioritizedFixList": [
    {
      "rank": 1,
      "caseId": "block.table.colspan",
      "totalOccurrences": 12,
      "affectedEpubs": 2,
      "impactScore": 36,
      "hint": "Check html.rs TableCell parsing for colspan attribute extraction"
    },
    {
      "rank": 2,
      "caseId": "inline.superscript",
      "totalOccurrences": 8,
      "affectedEpubs": 2,
      "impactScore": 8,
      "hint": "Check html.rs walk_inline_children() for <sup> tag handling"
    }
  ]
}
```

### Prioritized Fix List

The batch report ranks gaps by impact score and gives the AI Agent a clear priority order.

**Ranking rules (in order):**
1. `parser_error` entries always rank first (the parser cannot even run on that book)
2. Remaining gaps sorted by impact score: `occurrences * typeWeight * affectedEpubCount`
   - `missing_element`: typeWeight = 3
   - `over_converted`: typeWeight = 2
   - `feature_gap`: typeWeight = 1

### Console Output

The batch runner also prints a human-readable summary:

```
=== Batch Structural Check ===
Scanned: 25 EPUBs
Clean (0 gaps): 17
With gaps: 8 (total gapScore: 147)
Parser errors: 2

Top gaps to fix:
  1. block.table.colspan — 12 missing across 2 books (impact: 36)
  2. inline.superscript — 8 feature gaps across 2 books (impact: 8)
  3. block.image — 5 missing across 1 book (impact: 5)
  ...

Parser crashes:
  - kusamakura-japanese-vertical-writing.epub: unknown element: ruby
  - regime-anticancer-arabic.epub: unexpected bidi override
```

## Step 3: AI Agent Fix Loop

The AI Agent uses the batch report to drive a fix-verify cycle. This is orchestration guidance, not code — the AI Agent (Claude Code or similar) follows these instructions.

### Agent Instructions

```
You are fixing the EPUB parser to handle more content types.

SETUP:
1. Read batch_structural_report.json at build/reader_render_diff/batch_structural_report.json
2. Review the prioritizedFixList

FIX LOOP:
For each gap in prioritizedFixList, starting from rank 1:

  1. Read the gap's hint to locate the relevant code
     - Parser gaps: rust/epub_parser/src/html.rs (XHTML → RenderNode conversion)
     - Parser gaps: rust/epub_parser/src/model.rs (RenderNode type definitions)
     - Feature gaps: check both html.rs (parsing) and model.rs (data model)
  
  2. Understand the gap:
     - missing_element: a tag in XHTML has no corresponding RenderNode
     - feature_gap: a RenderNode exists but lacks an attribute (bold, align, etc.)
     - over_converted: a RenderNode exists but has no source XHTML element
     - parser_error: the parser panics on unknown input
  
  3. Make the fix in Rust/Dart code
  
  4. Verify on the specific EPUB that exposed the gap:
     node tool/reader_render_diff/run.mjs --structural-check --epub <affected_epub>
     Read the new structural_gaps.json — the specific gap should be gone
  
  5. Regression check on the simple books:
     node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/
     Confirm: no new gaps appeared in books that were previously clean
  
  6. If the fix introduced new gaps: revert and try a different approach
  
  7. Move to the next gap in the list

EXIT CONDITION:
  - All gaps in prioritizedFixList resolved, OR
  - Remaining gaps are in cases with status "unsupported" (deliberate scope limit)
  - Re-run full batch to confirm final state

CONSTRAINTS:
  - Do NOT modify case_catalog.json status fields to hide gaps
  - Do NOT modify the structural-check tool to suppress gaps
  - Only modify: rust/epub_parser/src/*, lib/services/reader/*
  - After fixing parser crashes, re-run batch to discover newly-visible gaps
```

### Iteration Strategy

Parser crashes are special: fixing a crash may reveal dozens of new structural gaps in that EPUB. The recommended order is:

1. Fix all `parser_error` entries first (unblock those EPUBs)
2. Re-run batch (newly parseable EPUBs will show their gaps)
3. Fix `missing_element` gaps by impact score
4. Fix `feature_gap` gaps by impact score
5. Investigate `over_converted` entries (lowest priority, may be benign)

## Scope Limits

- This spec does NOT change the existing `--structural-check` tool logic. V1 is used as-is.
- This spec does NOT address visual correctness. After structural gaps reach 0, a human reviews the full visual report separately.
- EPUB test suites that test reading system behavior (media overlays, scripting, fixed layout viewport) are out of scope — those test the app, not the parser.
- The batch runner is a thin orchestration layer, not a new test framework.

## Success Criteria

1. Batch runner completes on 25+ EPUBs without crashing
2. At least 5 EPUBs expose real structural gaps (not tool noise)
3. AI Agent can read `batch_structural_report.json` and follow the fix loop instructions without human intervention
4. Each parser fix reduces `totalGapScore` in the batch report
5. After a full fix cycle, the 6 original simple EPUBs still report 0 gaps (no regressions)

## Concrete Deliverables

1. `epubs/idpf-samples/` — 10+ IDPF sample EPUBs downloaded
2. `epubs/w3c-tests/` — relevant W3C conformance test EPUBs (cnt-*, css-* prefixes)
3. `tool/reader_render_diff/batch_structural_check.mjs` — batch runner script
4. `build/reader_render_diff/batch_structural_report.json` — first run output showing real gaps
5. This spec document as reference for the AI Agent fix loop
