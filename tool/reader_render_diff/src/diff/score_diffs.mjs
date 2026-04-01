import fs from 'node:fs/promises';
import path from 'node:path';

import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';

export async function scoreDiffs({
  referenceMetrics,
  canvasMetrics,
  alignedAnchors,
  anchorDiffs,
  allowlist,
  diffDir,
  outDir,
}) {
  await fs.mkdir(diffDir, { recursive: true });
  const pageDiffs = await diffPages(referenceMetrics, canvasMetrics, diffDir, outDir);
  const allDiffs = [...pageDiffs, ...anchorDiffs];
  const { annotatedDiffs, allowlistHits } = applyAllowlist(allDiffs, allowlist);
  const nonAllowlisted = annotatedDiffs.filter((diff) => !diff.allowlisted);
  const overallSeverity =
    nonAllowlisted.length === 0
      ? 0
      : nonAllowlisted.reduce((sum, diff) => sum + diff.severity, 0) / nonAllowlisted.length;

  const thresholdResult = {
    status: nonAllowlisted.some((diff) => diff.severity >= 0.6) || overallSeverity >= 0.25
      ? 'fail'
      : 'pass',
    overallSeverity,
    nonAllowlistedCount: nonAllowlisted.length,
  };

  return {
    overallSeverity,
    thresholdResult,
    allowlistHits,
    pageDiffs: annotatedDiffs.filter((diff) => diff.scope === 'page'),
    anchorDiffs: annotatedDiffs.filter((diff) => diff.scope === 'anchor'),
    chapterRanking: buildChapterRanking(annotatedDiffs),
    pageRanking: sortBySeverity(annotatedDiffs.filter((diff) => diff.scope === 'page')),
    anchorRanking: sortBySeverity(annotatedDiffs.filter((diff) => diff.scope === 'anchor')),
    alignedAnchors,
  };
}

async function diffPages(referenceMetrics, canvasMetrics, diffDir, outDir) {
  const referencePages = new Map(
    referenceMetrics.pages.map((page) => [pageKey(page.chapterIndex, page.pageIndex), page]),
  );
  const canvasPages = new Map(
    canvasMetrics.pages.map((page) => [pageKey(page.chapterIndex, page.pageIndex), page]),
  );
  const allKeys = new Set([...referencePages.keys(), ...canvasPages.keys()]);
  const diffs = [];

  for (const key of allKeys) {
    const referencePage = referencePages.get(key);
    const canvasPage = canvasPages.get(key);
    const [chapterIndexString, pageIndexString] = key.split(':');
    const chapterIndex = Number(chapterIndexString);
    const pageIndex = Number(pageIndexString);

    if (referencePage == null || canvasPage == null) {
      diffs.push({
        scope: 'page',
        diffType: 'missing-page',
        chapterIndex,
        pageIndex,
        severity: 1,
        allowlisted: false,
        details: {
          referencePresent: referencePage != null,
          canvasPresent: canvasPage != null,
        },
      });
      continue;
    }

    const diffImagePath = path.join(
      diffDir,
      'pages',
      `chapter_${String(chapterIndex).padStart(3, '0')}`,
      `page_${String(pageIndex).padStart(3, '0')}.png`,
    );
    const pixelDiffRatio = await buildPixelDiff(
      outDir,
      referencePage.screenshotPath,
      canvasPage.screenshotPath,
      diffImagePath,
    );
    const textMismatch = referencePage.normalizedText !== canvasPage.normalizedText;
    const blockCountDelta = Math.abs(referencePage.blocks.length - canvasPage.blocks.length);
    const severity = Math.min(
      1,
      pixelDiffRatio * 2 + (textMismatch ? 0.35 : 0) + Math.min(0.3, blockCountDelta * 0.06),
    );

    diffs.push({
      scope: 'page',
      diffType: 'page-visual-diff',
      chapterIndex,
      pageIndex,
      severity,
      allowlisted: false,
      details: {
        pixelDiffRatio,
        textMismatch,
        blockCountDelta,
        diffImagePath: path.relative(diffDir, diffImagePath),
        referenceScreenshotPath: referencePage.screenshotPath,
        canvasScreenshotPath: canvasPage.screenshotPath,
      },
    });
  }

  return diffs;
}

async function buildPixelDiff(outDir, referenceRelativePath, canvasRelativePath, outputPath) {
  const referencePath = path.join(outDir, 'reference', referenceRelativePath);
  const canvasPath = path.join(outDir, 'canvas', canvasRelativePath);
  const referenceImage = PNG.sync.read(await fs.readFile(referencePath));
  const canvasImage = PNG.sync.read(await fs.readFile(canvasPath));
  const width = Math.min(referenceImage.width, canvasImage.width);
  const height = Math.min(referenceImage.height, canvasImage.height);
  const diffImage = new PNG({ width, height });
  const diffPixels = pixelmatch(
    referenceImage.data,
    canvasImage.data,
    diffImage.data,
    width,
    height,
    { threshold: 0.1 },
  );
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, PNG.sync.write(diffImage));
  return diffPixels / (width * height);
}

function applyAllowlist(diffs, allowlist) {
  const entries = allowlist.entries ?? [];
  const hits = [];
  const annotated = diffs.map((diff) => {
    const matched = entries.find((entry) => matchesAllowlistEntry(diff, entry));
    if (matched == null) {
      return diff;
    }
    hits.push({
      diffType: diff.diffType,
      chapterIndex: diff.chapterIndex,
      pageIndex: diff.pageIndex,
      anchorHash: diff.anchorHash ?? null,
      note: matched.note ?? '',
    });
    return {
      ...diff,
      allowlisted: true,
      allowlistNote: matched.note ?? '',
    };
  });
  return {
    annotatedDiffs: annotated,
    allowlistHits: hits,
  };
}

function matchesAllowlistEntry(diff, entry) {
  if (entry.bookPathContains && !String(diff.bookPath ?? '').includes(entry.bookPathContains)) {
    return false;
  }
  if (entry.chapterIndex != null && entry.chapterIndex !== diff.chapterIndex) {
    return false;
  }
  if (entry.pageIndex != null && entry.pageIndex !== diff.pageIndex) {
    return false;
  }
  if (entry.diffType != null && entry.diffType !== diff.diffType) {
    return false;
  }
  if (entry.anchorHash != null && entry.anchorHash !== diff.anchorHash) {
    return false;
  }
  return true;
}

function buildChapterRanking(diffs) {
  const ranking = new Map();
  for (const diff of diffs) {
    const entry = ranking.get(diff.chapterIndex) ?? { chapterIndex: diff.chapterIndex, severity: 0, count: 0 };
    entry.severity = Math.max(entry.severity, diff.severity);
    entry.count += 1;
    ranking.set(diff.chapterIndex, entry);
  }
  return [...ranking.values()].sort((a, b) => b.severity - a.severity || b.count - a.count);
}

function sortBySeverity(diffs) {
  return [...diffs].sort((a, b) => b.severity - a.severity);
}

function pageKey(chapterIndex, pageIndex) {
  return `${chapterIndex}:${pageIndex}`;
}
