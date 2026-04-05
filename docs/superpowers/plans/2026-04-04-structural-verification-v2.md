# Structural Verification V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add EPUB test suites as test ammunition, build a batch runner to find real parser gaps across all EPUBs, and produce a prioritized fix list for the AI Agent fix loop.

**Architecture:** A batch script globs `.epub` files, runs the existing `--structural-check` pipeline on each, catches parser errors, and aggregates all results into one `batch_structural_report.json` with a ranked fix list. No changes to existing V1 tool code.

**Tech Stack:** Node.js (ESM), existing `run.mjs` infrastructure (config, cargo spawn, XHTML inventory, structural gaps), curl for downloads, git for IDPF samples.

**Spec:** `docs/superpowers/specs/2026-04-04-structural-verification-v2-design.md`

**Working directory:** `/Users/songtianjian/uni/uni`

## Execution Method: Subagent-Driven Development

Use `superpowers:subagent-driven-development` to execute this plan. Dispatch one subagent per task, review after each.

### Execution Flow

```
For each Task (1-7):
  1. Dispatch implementer subagent (general-purpose Agent)
     - Provide the FULL task text below (do NOT make subagent read this file)
     - Set working directory to /Users/songtianjian/uni/uni
     - Task 1-3 are download tasks: use model "haiku" (mechanical, no judgment needed)
     - Task 4 is the main coding task: use model "sonnet" (code is already written in plan, needs integration)
     - Task 5-7 are verification tasks: use model "haiku"
  
  2. If implementer reports DONE:
     - For Tasks 1-3, 6: skip reviews (pure download/config, no code to review)
     - For Task 4: run spec compliance review, then code quality review
     - For Tasks 5, 7: skip reviews (verification output, not code)
  
  3. If implementer reports BLOCKED or NEEDS_CONTEXT:
     - Provide missing context or re-dispatch with "opus" model
  
  4. Mark task complete in TodoWrite, move to next task

After all tasks:
  - Read build/reader_render_diff/_batch/batch_structural_report.json
  - Report summary to user: how many EPUBs scanned, gaps found, top issues
  - This report is the input for the AI Agent fix loop (Step 3 in spec)
```

### Key Context for All Subagents

Provide this to every implementer subagent:

```
Project: Flutter EPUB reader app at /Users/songtianjian/uni/uni
Tool location: tool/reader_render_diff/
Existing tool: run.mjs with --structural-check flag
  - Parses EPUB XHTML source, compares against Rust parser output
  - Reports structural gaps (missing elements, feature gaps, over-conversions)
  - Outputs: xhtml_inventory.json + structural_gaps.json
Key modules (DO NOT modify these):
  - src/xhtml/build_xhtml_inventory.mjs — XHTML inventory builder
  - src/xhtml/find_structural_gaps.mjs — gap detector
  - src/structural/resolve_chapters.mjs — chapter resolution from Rust parser output
  - src/cases/load_case_catalog.mjs — case catalog loader
  - src/config.mjs — CLI config parser
```

---

### Task 1: Download Rust Book EPUB and clean up PDF

**Files:**
- Delete: `epubs/The Rust Programming Language (Covers Rust 2018) (Steve Klabnik, Carol Nichols) (z-library.sk, 1lib.sk, z-lib.sk).pdf`
- Create: `epubs/The Rust Programming Language.epub`

- [ ] **Step 1: Download the official Rust Book EPUB**

```bash
curl -L -o "epubs/The Rust Programming Language.epub" https://doc.rust-lang.org/book/book.epub
```

Expected: file downloaded, ~2-5MB `.epub` file.

- [ ] **Step 2: Verify it is a valid EPUB (ZIP file with mimetype)**

```bash
file "epubs/The Rust Programming Language.epub"
```

Expected: output contains `Zip archive` or `EPUB`. If it says `HTML` or `text`, the URL may have changed — try `https://rust-lang.github.io/book/book.epub` instead.

- [ ] **Step 3: Remove the PDF**

```bash
rm "epubs/The Rust Programming Language (Covers Rust 2018) (Steve Klabnik, Carol Nichols) (z-library.sk, 1lib.sk, z-lib.sk).pdf"
```

- [ ] **Step 4: Commit**

```bash
git add "epubs/The Rust Programming Language.epub"
git add -u epubs/
git commit -m "chore: add Rust Book EPUB, remove PDF version"
```

---

### Task 2: Download IDPF EPUB 3 Sample Books

**Files:**
- Create: `epubs/idpf-samples/*.epub` (10 files)

- [ ] **Step 1: Create directory and download priority samples**

The IDPF samples are available as pre-built EPUBs from their GitHub releases page. Download the 10 priority samples listed in the spec.

```bash
mkdir -p epubs/idpf-samples
cd epubs/idpf-samples

# Base URL for IDPF release assets
BASE="https://github.com/IDPF/epub3-samples/releases/download/20230704"

curl -L -o accessible_epub_3.epub "$BASE/accessible_epub_3.epub"
curl -L -o linear-algebra.epub "$BASE/linear-algebra.epub"
curl -L -o kusamakura-japanese-vertical-writing.epub "$BASE/kusamakura-japanese-vertical-writing.epub"
curl -L -o wasteland-otf.epub "$BASE/wasteland-otf.epub"
curl -L -o cole-voyage-of-life-tol.epub "$BASE/cole-voyage-of-life-tol.epub"
curl -L -o childrens-media-query.epub "$BASE/childrens-media-query.epub"
curl -L -o indexing-for-eds-and-auths-3f.epub "$BASE/indexing-for-eds-and-auths-3f.epub"
curl -L -o regime-anticancer-arabic.epub "$BASE/regime-anticancer-arabic.epub"
curl -L -o figure-gallery-bindings.epub "$BASE/figure-gallery-bindings.epub"
curl -L -o moby-dick-mo.epub "$BASE/moby-dick-mo.epub"

cd ../..
```

Expected: 10 `.epub` files in `epubs/idpf-samples/`.

Note: If any download fails with 404, check the exact filenames at https://github.com/IDPF/epub3-samples/releases/tag/20230704 — some may have slightly different names (e.g. with underscores vs hyphens). Adjust the filename accordingly.

- [ ] **Step 2: Verify downloads are valid EPUBs**

```bash
for f in epubs/idpf-samples/*.epub; do echo "$(basename "$f"): $(file -b "$f" | head -c 40)"; done
```

Expected: all show `Zip archive` or `Java archive` (EPUBs are ZIP files). If any show `HTML document` or `ASCII text`, the download got a redirect page — retry with `-L` flag or download manually from the releases page.

- [ ] **Step 3: Commit**

```bash
git add epubs/idpf-samples/
git commit -m "chore: add 10 IDPF EPUB 3 sample books for structural testing"
```

---

### Task 3: Download W3C EPUB Conformance Tests

**Files:**
- Create: `epubs/w3c-tests/*.epub` (~45 files from cnt-*, css-*, pub-* prefixes)

- [ ] **Step 1: Clone the W3C test repo and generate EPUBs**

```bash
git clone --depth 1 https://github.com/w3c/epub-tests.git /tmp/epub-tests
cd /tmp/epub-tests/tests && bash generateEpubs.sh
cd -
```

Expected: ~204 `.epub` files generated in `/tmp/epub-tests/tests/`.

- [ ] **Step 2: Copy only the structurally relevant test EPUBs**

```bash
mkdir -p epubs/w3c-tests

# Content document tests (SVG, fonts, MathML, XHTML)
cp /tmp/epub-tests/tests/cnt-*.epub epubs/w3c-tests/ 2>/dev/null

# CSS tests (hyphens, line-break, writing-mode, text-emphasis, etc.)
cp /tmp/epub-tests/tests/css-*.epub epubs/w3c-tests/ 2>/dev/null

# Publication resource tests (media types, data URLs)
cp /tmp/epub-tests/tests/pub-*.epub epubs/w3c-tests/ 2>/dev/null
```

Expected: ~45 `.epub` files in `epubs/w3c-tests/`.

- [ ] **Step 3: Clean up temp directory**

```bash
rm -rf /tmp/epub-tests
```

- [ ] **Step 4: Verify and count**

```bash
ls epubs/w3c-tests/*.epub | wc -l
```

Expected: 30-50 files. If 0, the `generateEpubs.sh` script may have failed — check if `zip` command is available on the system.

- [ ] **Step 5: Commit**

```bash
git add epubs/w3c-tests/
git commit -m "chore: add W3C EPUB 3 conformance test EPUBs (cnt, css, pub prefixes)"
```

---

### Task 4: Write the Batch Structural Check Runner

**Files:**
- Create: `tool/reader_render_diff/batch_structural_check.mjs`

- [ ] **Step 1: Create the batch runner script**

Create `tool/reader_render_diff/batch_structural_check.mjs`:

```javascript
#!/usr/bin/env node

/**
 * Batch structural check runner.
 *
 * Runs --structural-check on every .epub in a directory and aggregates
 * results into a single batch_structural_report.json.
 *
 * Usage:
 *   node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/
 *   node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/ --recursive
 *   node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/idpf-samples/
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

import { loadCaseCatalog } from './src/cases/load_case_catalog.mjs';
import { buildXhtmlInventory } from './src/xhtml/build_xhtml_inventory.mjs';
import { findStructuralGaps } from './src/xhtml/find_structural_gaps.mjs';
import {
  resolveChapterXhtmlPaths,
  loadChapterJsons,
} from './src/structural/resolve_chapters.mjs';

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(TOOL_DIR, '..', '..');
const CATALOG_PATH = path.join(TOOL_DIR, 'case_catalog.json');

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next == null || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i++;
    }
  }
  return args;
}

// ---------------------------------------------------------------------------
// Discover EPUBs
// ---------------------------------------------------------------------------

async function discoverEpubs(dir, recursive) {
  const absDir = path.resolve(REPO_ROOT, dir);
  const results = [];

  async function scan(current) {
    const entries = await fs.readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isFile() && /\.epub$/i.test(entry.name)) {
        results.push(full);
      } else if (entry.isDirectory() && recursive) {
        await scan(full);
      }
    }
  }

  await scan(absDir);
  results.sort();
  return results;
}

// ---------------------------------------------------------------------------
// Run single EPUB structural check (in-process, no child spawn for check)
// ---------------------------------------------------------------------------

function runCommand(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const chunks = [];
    child.stderr.on('data', (chunk) => chunks.push(chunk));
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        const stderr = Buffer.concat(chunks).toString().trim();
        reject(new Error(stderr || `exit code ${code}`));
      }
    });
  });
}

function slugify(value) {
  return value
    .normalize('NFKD')
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();
}

async function runSingleCheck(epubPath, caseCatalog, batchOutDir) {
  const sampleName = path.basename(epubPath, '.epub');
  const slug = slugify(sampleName);
  const outDir = path.join(batchOutDir, slug);
  const cacheDir = path.join(outDir, 'cache');
  const extractedDir = path.join(outDir, 'input', 'extracted');

  await fs.mkdir(cacheDir, { recursive: true });
  await fs.mkdir(extractedDir, { recursive: true });

  // Unzip EPUB
  await runCommand('unzip', ['-o', '-q', epubPath, '-d', extractedDir], REPO_ROOT);

  // Run Rust parser
  await runCommand(
    'cargo',
    [
      'run', '--quiet',
      '--manifest-path', 'rust/epub_parser/Cargo.toml',
      '--', epubPath,
      '--batch-export', cacheDir,
    ],
    REPO_ROOT,
  );

  // Build config-like object for existing functions
  const config = {
    repoRoot: REPO_ROOT,
    epubPath,
    cacheDir,
    extractedDir,
    outDir,
    maxChapters: null, // full book
  };

  // Resolve chapters
  const xhtmlPaths = await resolveChapterXhtmlPaths(config);

  // Build XHTML inventory
  const xhtmlInventory = await buildXhtmlInventory({
    epubPath,
    xhtmlPaths,
    caseCatalog,
  });

  // Load chapter JSONs
  const chapterJsons = await loadChapterJsons(config, xhtmlPaths.length);

  // Find gaps
  const structuralGaps = findStructuralGaps({
    xhtmlInventory,
    chapterJsons,
    caseCatalog,
  });

  // Write per-epub artifacts
  await Promise.all([
    fs.writeFile(
      path.join(outDir, 'xhtml_inventory.json'),
      JSON.stringify(xhtmlInventory, null, 2),
    ),
    fs.writeFile(
      path.join(outDir, 'structural_gaps.json'),
      JSON.stringify(structuralGaps, null, 2),
    ),
  ]);

  return { slug, structuralGaps, xhtmlInventory };
}

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

function buildBatchReport(results, caseCatalog) {
  const report = {
    generatedAt: new Date().toISOString(),
    epubsScanned: results.length,
    epubsWithGaps: 0,
    epubsWithParserErrors: 0,
    epubsClean: 0,
    totalGapScore: 0,
    summary: { missingElements: 0, featureGaps: 0, overConvertedNodes: 0 },
    byCaseId: {},
    byEpub: [],
    prioritizedFixList: [],
  };

  for (const result of results) {
    if (result.status === 'parser_error') {
      report.epubsWithParserErrors++;
      report.byEpub.push({
        epub: result.epubPath,
        slug: result.slug,
        status: 'parser_error',
        error: result.error,
      });
      continue;
    }

    const gaps = result.structuralGaps;
    const s = gaps.summary;

    if (s.gapScore === 0) {
      report.epubsClean++;
      report.byEpub.push({
        epub: result.epubPath,
        slug: result.slug,
        status: 'clean',
        gapScore: 0,
      });
      continue;
    }

    report.epubsWithGaps++;
    report.totalGapScore += s.gapScore;
    report.summary.missingElements += s.missingElements;
    report.summary.featureGaps += s.featureGaps;
    report.summary.overConvertedNodes += s.overConvertedNodes;

    // Collect top gap case IDs
    const gapCaseIds = new Set();
    for (const gap of gaps.gaps) {
      const caseId = gap.blockCaseId ?? gap.missingFeature ?? gap.renderNodeKind ?? 'unknown';
      gapCaseIds.add(caseId);

      if (!report.byCaseId[caseId]) {
        report.byCaseId[caseId] = { missing: 0, featureGap: 0, overConverted: 0, epubs: [] };
      }
      const entry = report.byCaseId[caseId];
      if (gap.type === 'missing_element') entry.missing++;
      else if (gap.type === 'feature_gap') entry.featureGap++;
      else if (gap.type === 'over_converted') entry.overConverted++;

      if (!entry.epubs.includes(result.slug)) {
        entry.epubs.push(result.slug);
      }
    }

    report.byEpub.push({
      epub: result.epubPath,
      slug: result.slug,
      status: 'gaps_found',
      gapScore: s.gapScore,
      missingElements: s.missingElements,
      featureGaps: s.featureGaps,
      overConvertedNodes: s.overConvertedNodes,
      topGaps: [...gapCaseIds].slice(0, 5),
    });
  }

  // Build prioritized fix list
  // parser_error entries first
  const parserErrors = results
    .filter((r) => r.status === 'parser_error')
    .map((r, i) => ({
      rank: i + 1,
      type: 'parser_error',
      caseId: null,
      epub: r.slug,
      error: r.error,
      impactScore: Infinity,
      hint: `Rust parser crashes on this EPUB. Check rust/epub_parser/src/html.rs for panic or unhandled element. Error: ${r.error}`,
    }));

  // Gap entries ranked by impact
  const TYPE_WEIGHT = { missing: 3, overConverted: 2, featureGap: 1 };
  const gapEntries = [];
  for (const [caseId, data] of Object.entries(report.byCaseId)) {
    const totalOccurrences = data.missing + data.featureGap + data.overConverted;
    const weightedSum =
      data.missing * TYPE_WEIGHT.missing +
      data.featureGap * TYPE_WEIGHT.featureGap +
      data.overConverted * TYPE_WEIGHT.overConverted;
    const impactScore = weightedSum * data.epubs.length;

    // Determine dominant gap type for hint
    let dominantType = 'missing_element';
    if (data.featureGap > data.missing && data.featureGap > data.overConverted) {
      dominantType = 'feature_gap';
    } else if (data.overConverted > data.missing) {
      dominantType = 'over_converted';
    }

    // Look up case entry for hint
    const caseEntry = caseCatalog.byId[caseId];
    let hint = `Check rust/epub_parser/src/html.rs for "${caseId}" handling.`;
    if (caseEntry) {
      const tags = caseEntry.sourceHtmlTags?.join(', ') ?? caseId;
      if (dominantType === 'missing_element') {
        hint = `Parser does not produce RenderNode for <${tags}>. Check html.rs walk_children_of_node() or walk_inline_children().`;
      } else if (dominantType === 'feature_gap') {
        hint = `RenderNode exists but lacks "${caseId}" attribute. Check html.rs for <${tags}> style/attribute extraction.`;
      } else {
        hint = `Spurious RenderNode for "${caseId}". Check html.rs for over-generation from whitespace or flattened containers.`;
      }
    }

    gapEntries.push({
      caseId,
      totalOccurrences,
      affectedEpubs: data.epubs.length,
      impactScore,
      missing: data.missing,
      featureGap: data.featureGap,
      overConverted: data.overConverted,
      epubs: data.epubs,
      hint,
    });
  }

  gapEntries.sort((a, b) => b.impactScore - a.impactScore);

  // Merge: parser errors first, then gap entries
  let rank = parserErrors.length + 1;
  report.prioritizedFixList = [
    ...parserErrors,
    ...gapEntries.map((entry) => ({ rank: rank++, type: 'gap', ...entry })),
  ];

  return report;
}

// ---------------------------------------------------------------------------
// Console summary
// ---------------------------------------------------------------------------

function printSummary(report) {
  console.log('');
  console.log('=== Batch Structural Check ===');
  console.log(`Scanned: ${report.epubsScanned} EPUBs`);
  console.log(`Clean (0 gaps): ${report.epubsClean}`);
  console.log(`With gaps: ${report.epubsWithGaps} (total gapScore: ${report.totalGapScore})`);
  console.log(`Parser errors: ${report.epubsWithParserErrors}`);
  console.log('');

  if (report.prioritizedFixList.length > 0) {
    console.log('Top gaps to fix:');
    const displayCount = Math.min(report.prioritizedFixList.length, 10);
    for (let i = 0; i < displayCount; i++) {
      const item = report.prioritizedFixList[i];
      if (item.type === 'parser_error') {
        console.log(`  ${item.rank}. [CRASH] ${item.epub}: ${item.error.slice(0, 80)}`);
      } else {
        const total = item.totalOccurrences;
        const books = item.affectedEpubs;
        console.log(
          `  ${item.rank}. ${item.caseId} — ${total} occurrences across ${books} book(s) (impact: ${item.impactScore})`,
        );
      }
    }
    console.log('');
  }

  if (report.epubsWithParserErrors > 0) {
    console.log('Parser crashes:');
    for (const entry of report.byEpub.filter((e) => e.status === 'parser_error')) {
      console.log(`  - ${entry.slug}: ${entry.error.slice(0, 100)}`);
    }
    console.log('');
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const dir = args.dir;
  const recursive = Boolean(args.recursive);

  if (!dir) {
    console.error('Usage: node batch_structural_check.mjs --dir <epub-directory> [--recursive]');
    process.exitCode = 1;
    return;
  }

  const epubPaths = await discoverEpubs(dir, recursive);
  if (epubPaths.length === 0) {
    console.error(`No .epub files found in ${dir}${recursive ? ' (recursive)' : ''}`);
    process.exitCode = 1;
    return;
  }

  console.log(`Found ${epubPaths.length} EPUBs in ${dir}`);

  const caseCatalog = await loadCaseCatalog(CATALOG_PATH);
  const batchOutDir = path.join(REPO_ROOT, 'build', 'reader_render_diff', '_batch');
  await fs.mkdir(batchOutDir, { recursive: true });

  const results = [];

  for (let i = 0; i < epubPaths.length; i++) {
    const epubPath = epubPaths[i];
    const name = path.basename(epubPath, '.epub');
    const slug = slugify(name);
    const progress = `[${i + 1}/${epubPaths.length}]`;

    try {
      console.log(`${progress} Checking: ${name}`);
      const result = await runSingleCheck(epubPath, caseCatalog, batchOutDir);
      const score = result.structuralGaps.summary.gapScore;
      const label = score === 0 ? 'clean' : `gapScore=${score}`;
      console.log(`${progress} Done: ${name} — ${label}`);

      results.push({
        status: 'ok',
        epubPath,
        slug,
        structuralGaps: result.structuralGaps,
      });
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.log(`${progress} ERROR: ${name} — ${msg.slice(0, 100)}`);

      results.push({
        status: 'parser_error',
        epubPath,
        slug,
        error: msg,
      });
    }
  }

  // Build aggregate report
  const report = buildBatchReport(results, caseCatalog);

  // Write report
  const reportPath = path.join(batchOutDir, 'batch_structural_report.json');
  await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

  printSummary(report);
  console.log(`Full report: ${reportPath}`);

  // Exit with code 1 if any gaps or errors
  if (report.totalGapScore > 0 || report.epubsWithParserErrors > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
```

- [ ] **Step 2: Verify the script parses and runs on existing simple EPUBs**

Run on just the existing simple EPUBs first to make sure the pipeline works:

```bash
cd /Users/songtianjian/uni/uni
node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/ 2>&1 | head -30
```

Expected: all 6 original EPUBs show `clean` (gapScore=0), matching V1 behavior. The new complex books (Brief History, Sapiens, etc.) may show gaps or errors — that is expected and desired.

Note: The Rust parser compiles on the first EPUB run. Subsequent EPUBs reuse the cached binary. Total runtime for ~12 EPUBs: 1-3 minutes (most time is Rust compilation on first run).

- [ ] **Step 3: Fix any runtime issues**

Common problems:
- If `resolveChapterXhtmlPaths` fails, the Rust parser may not have generated `book.json` — check `cacheDir/book.json` exists
- If `unzip` fails on certain EPUBs, the file may be corrupted — skip it
- If `loadChapterJsons` returns all nulls, the chapter indices may not match — check `book.json` spine count

Fix any issues that arise. The script should be resilient — individual EPUB failures should be caught and recorded, not crash the batch.

- [ ] **Step 4: Commit**

```bash
git add tool/reader_render_diff/batch_structural_check.mjs
git commit -m "feat: add batch structural check runner for multi-EPUB gap detection"
```

---

### Task 5: Run First Batch on All EPUBs and Record Baseline

**Files:**
- Output: `build/reader_render_diff/_batch/batch_structural_report.json`

- [ ] **Step 1: Run batch on all EPUBs recursively**

```bash
cd /Users/songtianjian/uni/uni
node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/ --recursive
```

Expected: 20-50+ EPUBs processed. Some will be clean, some will show gaps, some may crash the parser. This is the whole point — we're finding real targets.

- [ ] **Step 2: Review the console output**

Check:
- How many EPUBs are clean vs have gaps vs crash?
- What are the top gaps? Are they real parser gaps or tool noise?
- Do any parser crashes indicate genuine missing features (e.g., `<ruby>`, `<svg>`, `<math>`)?

- [ ] **Step 3: Review the batch report**

```bash
cat build/reader_render_diff/_batch/batch_structural_report.json | head -80
```

Verify:
- `prioritizedFixList` is non-empty (we found real targets)
- `byCaseId` shows which content types are problematic
- `byEpub` shows which books are most affected

- [ ] **Step 4: If batch report shows 0 gaps across all EPUBs**

This means even the complex books don't stress the parser. Check:
- Are the IDPF samples actually using complex features? Run `unzip -l epubs/idpf-samples/linear-algebra.epub | grep xhtml` to verify chapter files exist.
- Are the W3C test EPUBs structurally meaningful? They may be too minimal (one element per EPUB).
- Consider adding more complex real-world EPUBs.

- [ ] **Step 5: Commit the first batch report as baseline reference**

```bash
mkdir -p docs/superpowers/baselines
cp build/reader_render_diff/_batch/batch_structural_report.json docs/superpowers/baselines/2026-04-04-batch-structural-baseline.json
git add docs/superpowers/baselines/
git commit -m "docs: record first batch structural check baseline across all test EPUBs"
```

---

### Task 6: Add .gitignore Entries for EPUB Test Data

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Check current .gitignore for EPUB patterns**

```bash
grep -n epub .gitignore 2>/dev/null || echo "no epub entries"
grep -n build .gitignore 2>/dev/null || echo "no build entries"
```

- [ ] **Step 2: Add entries if not already present**

Add to `.gitignore` (only if missing):

```
# EPUB test data (large binary files, download via plan steps)
epubs/idpf-samples/
epubs/w3c-tests/

# Batch structural check output
build/reader_render_diff/_batch/
```

Note: The existing `./epubs/*.epub` files (real books from z-library) should already be gitignored or tracked per project convention. Do NOT gitignore the original 6 simple EPUBs if they are currently tracked.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore EPUB test suites and batch check output"
```

---

### Task 7: Verify End-to-End and Document Usage

- [ ] **Step 1: Run the full pipeline from scratch**

Clean and re-run to verify everything works:

```bash
rm -rf build/reader_render_diff/_batch/
node tool/reader_render_diff/batch_structural_check.mjs --dir epubs/ --recursive
```

Expected: completes without script crashes, produces `batch_structural_report.json`.

- [ ] **Step 2: Verify single-EPUB check still works**

```bash
node tool/reader_render_diff/run.mjs --structural-check --epub "epubs/Project Hail Mary (Andy Weir) (z-library.sk, 1lib.sk, z-lib.sk)_副本.epub"
```

Expected: same output as before, 0 gaps. Existing behavior unchanged.

- [ ] **Step 3: Verify batch report is usable by AI Agent**

Read the `prioritizedFixList` from the batch report:

```bash
node -e "
const r = require('./build/reader_render_diff/_batch/batch_structural_report.json');
console.log('Total gaps:', r.totalGapScore);
console.log('Fix list entries:', r.prioritizedFixList.length);
r.prioritizedFixList.slice(0, 3).forEach(f => console.log(f.rank, f.caseId ?? f.epub, f.hint?.slice(0, 80)));
"
```

Expected: readable output with ranks, case IDs, and actionable hints.

- [ ] **Step 4: Final commit**

```bash
git add -A
git status
```

If there are unstaged changes from fixes made during this task, commit them:

```bash
git commit -m "fix: address issues found during end-to-end verification"
```
