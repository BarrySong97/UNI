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
  const annotatedPageDiffs = annotatedDiffs.filter((diff) => diff.scope === 'page');
  const annotatedAnchorDiffs = annotatedDiffs.filter((diff) => diff.scope === 'anchor');
  const matchedPageDiffs = annotatedPageDiffs.filter(hasComparableScreenshots);
  const unmatchedPageDiffs = annotatedPageDiffs.filter(
    (diff) => !hasComparableScreenshots(diff),
  );
  const visualDistance =
    annotatedDiffs.length === 0
      ? 0
      : annotatedDiffs.reduce((sum, diff) => sum + diff.severity, 0) / annotatedDiffs.length;

  return {
    visualDistance,
    allowlistHits,
    pageDiffs: annotatedPageDiffs,
    matchedPageDiffs,
    unmatchedPageDiffs,
    anchorDiffs: annotatedAnchorDiffs,
    chapterRanking: buildChapterRanking({
      referenceMetrics,
      canvasMetrics,
      pageDiffs: annotatedPageDiffs,
      anchorDiffs: annotatedAnchorDiffs,
    }),
    pageRanking: sortBySeverity(matchedPageDiffs),
    unmatchedPageRanking: sortBySeverity(unmatchedPageDiffs),
    anchorRanking: sortBySeverity(annotatedAnchorDiffs),
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
          referenceScreenshotPath: referencePage?.screenshotPath ?? null,
          canvasScreenshotPath: canvasPage?.screenshotPath ?? null,
          observation:
            referencePage == null
              ? 'Browser reference did not produce a comparable screenshot for this page key.'
              : 'Canvas renderer did not produce a comparable screenshot for this page key.',
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
        observation: buildObservation({ pixelDiffRatio, textMismatch, blockCountDelta }),
        diffImagePath: path.relative(diffDir, diffImagePath),
        referenceScreenshotPath: referencePage.screenshotPath,
        canvasScreenshotPath: canvasPage.screenshotPath,
      },
    });
  }

  return diffs;
}

function buildObservation({ pixelDiffRatio, textMismatch, blockCountDelta }) {
  const parts = [];
  if (pixelDiffRatio > 0.08) {
    parts.push('large visual delta');
  } else if (pixelDiffRatio > 0.02) {
    parts.push('visible visual delta');
  } else {
    parts.push('small visual delta');
  }
  if (textMismatch) {
    parts.push('visible text differs');
  }
  if (blockCountDelta > 0) {
    parts.push(`block count delta ${blockCountDelta}`);
  }
  return parts.join(', ');
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

function buildChapterRanking({ referenceMetrics, canvasMetrics, pageDiffs, anchorDiffs }) {
  const chapterIndices = new Set([
    ...Object.keys(referenceMetrics.chapterPageCounts ?? {}).map(Number),
    ...Object.keys(canvasMetrics.chapterPageCounts ?? {}).map(Number),
    ...pageDiffs.map((diff) => diff.chapterIndex),
    ...anchorDiffs.map((diff) => diff.chapterIndex),
  ]);
  const ranking = new Map();

  for (const chapterIndex of chapterIndices) {
    ranking.set(chapterIndex, {
      chapterIndex,
      severity: 0,
      count: 0,
      matchedPageCount: 0,
      unmatchedPageCount: 0,
      anchorDiffCount: 0,
      referencePageCount: Number(referenceMetrics.chapterPageCounts?.[String(chapterIndex)] ?? 0),
      canvasPageCount: Number(canvasMetrics.chapterPageCounts?.[String(chapterIndex)] ?? 0),
    });
  }

  for (const diff of [...pageDiffs, ...anchorDiffs]) {
    const entry =
      ranking.get(diff.chapterIndex) ?? {
        chapterIndex: diff.chapterIndex,
        severity: 0,
        count: 0,
        matchedPageCount: 0,
        unmatchedPageCount: 0,
        anchorDiffCount: 0,
        referencePageCount: 0,
        canvasPageCount: 0,
      };
    entry.severity = Math.max(entry.severity, diff.severity);
    if (diff.scope === 'page') {
      if (hasComparableScreenshots(diff)) {
        entry.matchedPageCount += 1;
      } else {
        entry.unmatchedPageCount += 1;
      }
    } else if (diff.scope === 'anchor') {
      entry.anchorDiffCount += 1;
    }
    entry.count = entry.matchedPageCount + entry.unmatchedPageCount;
    ranking.set(diff.chapterIndex, entry);
  }

  return [...ranking.values()].sort(
    (a, b) =>
      b.severity - a.severity ||
      b.unmatchedPageCount - a.unmatchedPageCount ||
      b.matchedPageCount - a.matchedPageCount ||
      b.anchorDiffCount - a.anchorDiffCount,
  );
}

function sortBySeverity(diffs) {
  return [...diffs].sort((a, b) => b.severity - a.severity);
}

function hasComparableScreenshots(diff) {
  const details = diff.details ?? {};
  return (
    details.referenceScreenshotPath != null &&
    details.referenceScreenshotPath !== '' &&
    details.canvasScreenshotPath != null &&
    details.canvasScreenshotPath !== ''
  );
}

function pageKey(chapterIndex, pageIndex) {
  return `${chapterIndex}:${pageIndex}`;
}
