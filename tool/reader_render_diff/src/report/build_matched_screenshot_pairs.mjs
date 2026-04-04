import path from 'node:path';

import { excerptText } from '../shared/text_utils.mjs';
import { writeCrop } from './crop_png.mjs';

const MATCH_KIND_RANK = {
  exact: 3,
  canonical_exact: 2,
  image_signature_exact: 1,
};

export function matchContentObjects({ browserObjects, canvasObjects }) {
  const browserByChapter = groupByChapter(browserObjects);
  const canvasByChapter = groupByChapter(canvasObjects);
  const matched = [];

  for (const chapterIndex of unionKeys(browserByChapter, canvasByChapter)) {
    const browserChapterObjects = browserByChapter.get(chapterIndex) ?? [];
    const canvasChapterObjects = canvasByChapter.get(chapterIndex) ?? [];
    const candidates = buildCandidates(browserChapterObjects, canvasChapterObjects);
    const browserTop = bestCandidatesByKey(candidates, 'browserObjectId');
    const canvasTop = bestCandidatesByKey(candidates, 'canvasObjectId');
    const ambiguousBrowserIds = collectAmbiguousIds(candidates, browserTop, 'browserObjectId');
    const ambiguousCanvasIds = collectAmbiguousIds(candidates, canvasTop, 'canvasObjectId');

    for (const candidate of candidates) {
      if (ambiguousBrowserIds.has(candidate.browserObjectId)) {
        continue;
      }
      if (ambiguousCanvasIds.has(candidate.canvasObjectId)) {
        continue;
      }
      const browserBest = browserTop.get(candidate.browserObjectId);
      const canvasBest = canvasTop.get(candidate.canvasObjectId);
      if (browserBest == null || canvasBest == null) {
        continue;
      }
      if (browserBest.id !== candidate.id || canvasBest.id !== candidate.id) {
        continue;
      }

      matched.push({
        matchId: candidate.id,
        chapterIndex,
        browserObjectId: candidate.browserObjectId,
        canvasObjectId: candidate.canvasObjectId,
        blockCaseId: candidate.blockCaseId,
        featureCaseIds: candidate.sharedFeatureCaseIds,
        matchKind: candidate.matchKind,
        confidence: 1.0,
        textExcerpt: candidate.excerpt,
      });
    }
  }

  return matched.sort(
    (a, b) =>
      a.chapterIndex - b.chapterIndex ||
      a.blockCaseId.localeCompare(b.blockCaseId) ||
      a.browserObjectId.localeCompare(b.browserObjectId),
  );
}

export async function buildMatchedScreenshotPairs({
  outDir,
  referenceMetrics,
  canvasMetrics,
  matchedObjects,
  browserObjects,
  canvasObjects,
}) {
  const browserById = new Map(browserObjects.map((item) => [item.objectId, item]));
  const canvasById = new Map(canvasObjects.map((item) => [item.objectId, item]));
  const imageCache = new Map();
  const comparisons = [];

  for (const match of matchedObjects ?? []) {
    if (match.matchKind !== 'exact' && match.matchKind !== 'canonical_exact') {
      continue;
    }
    if (match.blockCaseId === 'block.horizontal_rule') {
      continue;
    }

    const browserObject = browserById.get(match.browserObjectId);
    const canvasObject = canvasById.get(match.canvasObjectId);
    if (browserObject == null || canvasObject == null) {
      continue;
    }
    const browserAppearance = browserObject.appearances?.[0];
    const canvasAppearance = canvasObject.appearances?.[0];
    if (
      browserAppearance?.rect == null ||
      browserAppearance.screenshotPath == null ||
      canvasAppearance?.rect == null ||
      canvasAppearance.screenshotPath == null
    ) {
      continue;
    }

    const baseName = `${match.matchId.replaceAll(':', '_')}`;
    const browserCropPath = await writeCrop({
      imageCache,
      sourcePath: path.join(outDir, 'reference', browserAppearance.screenshotPath),
      outputPath: path.join(
        outDir,
        'report_assets',
        'matched_objects',
        `chapter_${String(match.chapterIndex).padStart(3, '0')}`,
        `${baseName}_browser.png`,
      ),
      rect: browserAppearance.rect,
      devicePixelRatio: referenceMetrics.devicePixelRatio,
    });
    const canvasCropPath = await writeCrop({
      imageCache,
      sourcePath: path.join(outDir, 'canvas', canvasAppearance.screenshotPath),
      outputPath: path.join(
        outDir,
        'report_assets',
        'matched_objects',
        `chapter_${String(match.chapterIndex).padStart(3, '0')}`,
        `${baseName}_canvas.png`,
      ),
      rect: canvasAppearance.rect,
      devicePixelRatio: canvasMetrics.devicePixelRatio,
    });
    if (browserCropPath == null || canvasCropPath == null) {
      continue;
    }

    comparisons.push({
      matchId: match.matchId,
      chapterIndex: match.chapterIndex,
      blockCaseId: match.blockCaseId,
      featureCaseIds: match.featureCaseIds,
      matchKind: match.matchKind,
      confidence: match.confidence,
      excerpt: excerptText(browserObject.text || canvasObject.text || ''),
      browserPageIndex: browserAppearance.pageIndex,
      canvasPageIndex: canvasAppearance.pageIndex,
      browserCropPath: path.relative(outDir, browserCropPath).replaceAll('\\', '/'),
      canvasCropPath: path.relative(outDir, canvasCropPath).replaceAll('\\', '/'),
      browserObjectId: browserObject.objectId,
      canvasObjectId: canvasObject.objectId,
    });
  }

  return comparisons.sort(
    (a, b) => a.chapterIndex - b.chapterIndex || a.browserPageIndex - b.browserPageIndex,
  );
}

function buildCandidates(browserObjects, canvasObjects) {
  const candidates = [];

  for (const browserObject of browserObjects) {
    if (!browserObject.matchEligible) {
      continue;
    }
    for (const canvasObject of canvasObjects) {
      if (!canvasObject.matchEligible) {
        continue;
      }
      if (browserObject.blockCaseId !== canvasObject.blockCaseId) {
        continue;
      }

      const matchKind = classifyMatch(browserObject, canvasObject);
      if (matchKind == null) {
        continue;
      }

      const sharedFeatureCaseIds = intersection(
        browserObject.featureCaseIds ?? [],
        canvasObject.featureCaseIds ?? [],
      );
      candidates.push({
        id: `match:${browserObject.chapterIndex}:${browserObject.objectId}:${canvasObject.objectId}`,
        chapterIndex: browserObject.chapterIndex,
        browserObjectId: browserObject.objectId,
        canvasObjectId: canvasObject.objectId,
        blockCaseId: browserObject.blockCaseId,
        browserOrdinal: browserObject.ordinal ?? 0,
        canvasOrdinal: canvasObject.ordinal ?? 0,
        matchKind,
        featureExact: arrayEquals(
          browserObject.featureCaseIds ?? [],
          canvasObject.featureCaseIds ?? [],
        ),
        alignExact: extractAlign(browserObject) === extractAlign(canvasObject),
        ordinalDistance: Math.abs((browserObject.ordinal ?? 0) - (canvasObject.ordinal ?? 0)),
        sharedFeatureCaseIds,
        excerpt: excerptText(browserObject.text || canvasObject.text || ''),
      });
    }
  }

  return candidates.sort(compareCandidate);
}

function classifyMatch(browserObject, canvasObject) {
  if (
    browserObject.blockCaseId === 'block.image' &&
    browserObject.imageSignature != null &&
    browserObject.imageSignature === canvasObject.imageSignature
  ) {
    return 'image_signature_exact';
  }
  if (
    browserObject.normalizedText != null &&
    browserObject.normalizedText !== '' &&
    browserObject.normalizedText === canvasObject.normalizedText
  ) {
    return 'exact';
  }
  if (
    browserObject.canonicalText != null &&
    browserObject.canonicalText !== '' &&
    browserObject.canonicalText === canvasObject.canonicalText
  ) {
    return 'canonical_exact';
  }
  return null;
}

function compareCandidate(a, b) {
  return (
    MATCH_KIND_RANK[b.matchKind] - MATCH_KIND_RANK[a.matchKind] ||
    Number(b.featureExact) - Number(a.featureExact) ||
    Number(b.alignExact) - Number(a.alignExact) ||
    a.ordinalDistance - b.ordinalDistance ||
    a.browserOrdinal - b.browserOrdinal ||
    a.canvasOrdinal - b.canvasOrdinal ||
    a.id.localeCompare(b.id)
  );
}

function bestCandidatesByKey(candidates, key) {
  const grouped = new Map();
  for (const candidate of candidates) {
    const list = grouped.get(candidate[key]) ?? [];
    list.push(candidate);
    grouped.set(candidate[key], list);
  }

  const top = new Map();
  for (const [groupKey, list] of grouped.entries()) {
    const sorted = [...list].sort(compareCandidate);
    top.set(groupKey, sorted[0]);
  }
  return top;
}

function collectAmbiguousIds(candidates, topByKey, key) {
  const grouped = new Map();
  for (const candidate of candidates) {
    const list = grouped.get(candidate[key]) ?? [];
    list.push(candidate);
    grouped.set(candidate[key], list);
  }

  const ambiguous = new Set();
  for (const [groupKey, list] of grouped.entries()) {
    const sorted = [...list].sort(compareCandidate);
    if (sorted.length < 2) {
      continue;
    }
    if (candidateScore(sorted[0]) === candidateScore(sorted[1])) {
      ambiguous.add(groupKey);
    }
    if (topByKey.get(groupKey) == null) {
      ambiguous.add(groupKey);
    }
  }
  return ambiguous;
}

function candidateScore(candidate) {
  return [
    MATCH_KIND_RANK[candidate.matchKind],
    Number(candidate.featureExact),
    Number(candidate.alignExact),
    -candidate.ordinalDistance,
  ].join('|');
}

function groupByChapter(items) {
  const grouped = new Map();
  for (const item of items ?? []) {
    const list = grouped.get(item.chapterIndex) ?? [];
    list.push(item);
    grouped.set(item.chapterIndex, list);
  }
  return grouped;
}

function unionKeys(a, b) {
  return [...new Set([...a.keys(), ...b.keys()])].sort((x, y) => x - y);
}

function extractAlign(object) {
  return (
    object.computedStyleSummary?.textAlign ??
    object.rawNodeSummary?.align ??
    null
  );
}

function arrayEquals(a, b) {
  if (a.length !== b.length) {
    return false;
  }
  return a.every((value, index) => value === b[index]);
}

function intersection(a, b) {
  const right = new Set(b);
  return a.filter((value) => right.has(value));
}
