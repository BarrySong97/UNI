#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

import { loadCaseCatalog } from './src/cases/load_case_catalog.mjs';
import { buildXhtmlInventory } from './src/xhtml/build_xhtml_inventory.mjs';
import { findStructuralGaps } from './src/xhtml/find_structural_gaps.mjs';
import {
  loadChapterJsons,
  resolveChapterXhtmlPaths,
} from './src/structural/resolve_chapters.mjs';

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(TOOL_DIR, '..', '..');
const CATALOG_PATH = path.join(TOOL_DIR, 'case_catalog.json');

export function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }
    const key = token.slice(2);
    const next = argv[index + 1];
    if (next == null || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    index += 1;
  }
  return args;
}

export async function discoverEpubs(dir, recursive) {
  const absDir = path.resolve(REPO_ROOT, dir);
  const results = [];

  async function scan(currentDir) {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isFile() && /\.epub$/i.test(entry.name)) {
        results.push(fullPath);
      } else if (entry.isDirectory() && recursive) {
        await scan(fullPath);
      }
    }
  }

  await scan(absDir);
  results.sort();
  return results;
}

function toRepoRelativePath(targetPath) {
  const relativePath = path.relative(REPO_ROOT, targetPath);
  if (relativePath === '') {
    return '.';
  }
  return relativePath.startsWith('..') ? targetPath : relativePath;
}

function runCommand(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    const stderrChunks = [];
    child.stderr.on('data', (chunk) => stderrChunks.push(chunk));
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      const stderr = Buffer.concat(stderrChunks).toString().trim();
      reject(new Error(stderr || `${command} ${args.join(' ')} failed with exit code ${code}`));
    });
  });
}

async function extractEpub(epubPath, extractedDir) {
  try {
    await runCommand('unzip', ['-o', '-q', epubPath, '-d', extractedDir], REPO_ROOT);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.includes('Illegal byte sequence')) {
      throw error;
    }

    await runCommand('ditto', ['-x', '-k', epubPath, extractedDir], REPO_ROOT);
  }
}

export function slugify(value) {
  const slug = value
    .normalize('NFKD')
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();

  if (slug !== '') {
    return slug;
  }

  return `epub-${Buffer.from(value).toString('hex').slice(0, 16)}`;
}

async function runSingleCheck(epubPath, caseCatalog, batchOutDir) {
  const sampleName = path.basename(epubPath, '.epub');
  const slug = slugify(sampleName);
  const outDir = path.join(batchOutDir, slug);
  const cacheDir = path.join(outDir, 'cache');
  const extractedDir = path.join(outDir, 'input', 'extracted');

  await fs.mkdir(cacheDir, { recursive: true });
  await fs.mkdir(extractedDir, { recursive: true });

  await extractEpub(epubPath, extractedDir);
  await runCommand(
    'cargo',
    [
      'run',
      '--quiet',
      '--manifest-path',
      'rust/epub_parser/Cargo.toml',
      '--',
      epubPath,
      '--batch-export',
      cacheDir,
    ],
    REPO_ROOT,
  );

  const config = {
    repoRoot: REPO_ROOT,
    epubPath,
    cacheDir,
    extractedDir,
    outDir,
    maxChapters: null,
  };

  const xhtmlPaths = await resolveChapterXhtmlPaths(config);
  const xhtmlInventory = await buildXhtmlInventory({
    epubPath,
    xhtmlPaths,
    caseCatalog,
  });
  const chapterJsons = await loadChapterJsons(config, xhtmlPaths.length);
  const structuralGaps = findStructuralGaps({
    xhtmlInventory,
    chapterJsons,
    caseCatalog,
  });

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

  return { slug, structuralGaps };
}

export function buildBatchReport(results, caseCatalog) {
  const report = {
    generatedAt: new Date().toISOString(),
    epubsScanned: results.length,
    epubsWithGaps: 0,
    epubsWithParserErrors: 0,
    epubsClean: 0,
    totalGapScore: 0,
    summary: {
      missingElements: 0,
      featureGaps: 0,
      overConvertedNodes: 0,
    },
    byCaseId: {},
    byEpub: [],
    prioritizedFixList: [],
  };

  for (const result of results) {
    if (result.status === 'parser_error') {
      report.epubsWithParserErrors += 1;
      report.byEpub.push({
        epub: toRepoRelativePath(result.epubPath),
        slug: result.slug,
        status: 'parser_error',
        error: result.error,
      });
      continue;
    }

    const summary = result.structuralGaps.summary;
    if (summary.gapScore === 0) {
      report.epubsClean += 1;
      report.byEpub.push({
        epub: toRepoRelativePath(result.epubPath),
        slug: result.slug,
        status: 'clean',
        gapScore: 0,
      });
      continue;
    }

    report.epubsWithGaps += 1;
    report.totalGapScore += summary.gapScore;
    report.summary.missingElements += summary.missingElements;
    report.summary.featureGaps += summary.featureGaps;
    report.summary.overConvertedNodes += summary.overConvertedNodes;

    const gapCaseIds = new Set();
    for (const gap of result.structuralGaps.gaps) {
      const caseId = gap.blockCaseId ?? gap.missingFeature ?? gap.renderNodeKind ?? 'unknown';
      gapCaseIds.add(caseId);

      if (report.byCaseId[caseId] == null) {
        report.byCaseId[caseId] = {
          missing: 0,
          featureGap: 0,
          overConverted: 0,
          epubs: [],
        };
      }

      const entry = report.byCaseId[caseId];
      if (gap.type === 'missing_element') {
        entry.missing += 1;
      } else if (gap.type === 'feature_gap') {
        entry.featureGap += 1;
      } else if (gap.type === 'over_converted') {
        entry.overConverted += 1;
      }

      if (!entry.epubs.includes(result.slug)) {
        entry.epubs.push(result.slug);
      }
    }

    report.byEpub.push({
      epub: toRepoRelativePath(result.epubPath),
      slug: result.slug,
      status: 'gaps_found',
      gapScore: summary.gapScore,
      missingElements: summary.missingElements,
      featureGaps: summary.featureGaps,
      overConvertedNodes: summary.overConvertedNodes,
      topGaps: [...gapCaseIds].slice(0, 5),
    });
  }

  const parserErrors = results
    .filter((result) => result.status === 'parser_error')
    .map((result, index) => ({
      rank: index + 1,
      type: 'parser_error',
      caseId: null,
      epub: result.slug,
      error: result.error,
      impactScore: Number.POSITIVE_INFINITY,
      hint:
        'Rust parser crashes on this EPUB. Check rust/epub_parser/src/html.rs for panic or unhandled input.',
    }));

  const TYPE_WEIGHT = {
    missing: 3,
    overConverted: 2,
    featureGap: 1,
  };

  const gapEntries = Object.entries(report.byCaseId).map(([caseId, data]) => {
    const totalOccurrences = data.missing + data.featureGap + data.overConverted;
    const weightedSum =
      (data.missing * TYPE_WEIGHT.missing) +
      (data.overConverted * TYPE_WEIGHT.overConverted) +
      (data.featureGap * TYPE_WEIGHT.featureGap);
    const impactScore = weightedSum * data.epubs.length;

    let dominantType = 'missing_element';
    if (data.featureGap > data.missing && data.featureGap > data.overConverted) {
      dominantType = 'feature_gap';
    } else if (data.overConverted > data.missing) {
      dominantType = 'over_converted';
    }

    const caseEntry = caseCatalog.byId[caseId];
    let hint = `Check rust/epub_parser/src/html.rs for "${caseId}" handling.`;
    if (caseEntry != null) {
      const tags = caseEntry.sourceHtmlTags?.join(', ') ?? caseId;
      if (dominantType === 'missing_element') {
        hint =
          `Parser does not produce RenderNode for <${tags}>. ` +
          'Check html.rs walk_children_of_node() or walk_inline_children().';
      } else if (dominantType === 'feature_gap') {
        hint =
          `RenderNode exists but lacks "${caseId}" attribute. ` +
          `Check html.rs for <${tags}> style or attribute extraction.`;
      } else {
        hint =
          `Spurious RenderNode for "${caseId}". ` +
          'Check html.rs for over-generation from whitespace or flattened containers.';
      }
    }

    return {
      caseId,
      totalOccurrences,
      affectedEpubs: data.epubs.length,
      impactScore,
      missing: data.missing,
      featureGap: data.featureGap,
      overConverted: data.overConverted,
      epubs: data.epubs,
      hint,
    };
  });

  gapEntries.sort((left, right) => {
    if (right.impactScore !== left.impactScore) {
      return right.impactScore - left.impactScore;
    }
    return left.caseId.localeCompare(right.caseId);
  });

  report.prioritizedFixList = [
    ...parserErrors,
    ...gapEntries.map((entry, index) => ({
      rank: parserErrors.length + index + 1,
      type: 'gap',
      ...entry,
    })),
  ];

  return report;
}

export function printSummary(report) {
  console.log('');
  console.log('=== Batch Structural Check ===');
  console.log(`Scanned: ${report.epubsScanned} EPUBs`);
  console.log(`Clean (0 gaps): ${report.epubsClean}`);
  console.log(`With gaps: ${report.epubsWithGaps} (total gapScore: ${report.totalGapScore})`);
  console.log(`Parser errors: ${report.epubsWithParserErrors}`);
  console.log('');

  if (report.prioritizedFixList.length > 0) {
    console.log('Top gaps to fix:');
    for (const item of report.prioritizedFixList.slice(0, 10)) {
      if (item.type === 'parser_error') {
        console.log(`  ${item.rank}. [CRASH] ${item.epub}: ${item.error.slice(0, 80)}`);
      } else {
        console.log(
          `  ${item.rank}. ${item.caseId} — ${item.totalOccurrences} occurrences across ${item.affectedEpubs} book(s) (impact: ${item.impactScore})`,
        );
      }
    }
    console.log('');
  }

  if (report.epubsWithParserErrors > 0) {
    console.log('Parser crashes:');
    for (const entry of report.byEpub.filter((item) => item.status === 'parser_error')) {
      console.log(`  - ${entry.slug}: ${entry.error.slice(0, 100)}`);
    }
    console.log('');
  }
}

export async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const dir = args.dir;
  const recursive = Boolean(args.recursive);

  if (dir == null) {
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
  for (let index = 0; index < epubPaths.length; index += 1) {
    const epubPath = epubPaths[index];
    const name = path.basename(epubPath, '.epub');
    const slug = slugify(name);
    const progress = `[${index + 1}/${epubPaths.length}]`;

    try {
      console.log(`${progress} Checking: ${name}`);
      const result = await runSingleCheck(epubPath, caseCatalog, batchOutDir);
      const gapScore = result.structuralGaps.summary.gapScore;
      console.log(
        `${progress} Done: ${name} — ${gapScore === 0 ? 'clean' : `gapScore=${gapScore}`}`,
      );
      results.push({
        status: 'ok',
        epubPath,
        slug,
        structuralGaps: result.structuralGaps,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.log(`${progress} ERROR: ${name} — ${message.slice(0, 100)}`);
      results.push({
        status: 'parser_error',
        epubPath,
        slug,
        error: message,
      });
    }
  }

  const report = buildBatchReport(results, caseCatalog);
  const reportPath = path.join(batchOutDir, 'batch_structural_report.json');
  await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

  printSummary(report);
  console.log(`Full report: ${reportPath}`);

  if (report.totalGapScore > 0 || report.epubsWithParserErrors > 0) {
    process.exitCode = 1;
  }
}

const isMain =
  process.argv[1] != null &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
