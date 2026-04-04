import path from 'node:path';

import { excerptText } from '../shared/text_utils.mjs';
import { writeCrop } from '../report/crop_png.mjs';

export async function findMissingConversions({
  outDir,
  referenceMetrics,
  browserObjects,
  matchedObjects,
  caseCatalog,
}) {
  const matchedBrowserIds = new Set((matchedObjects ?? []).map((item) => item.browserObjectId));
  const imageCache = new Map();
  const missing = [];

  for (const object of browserObjects ?? []) {
    const caseEntry = caseCatalog.byId[object.blockCaseId];
    if (caseEntry == null) {
      continue;
    }
    if (caseEntry.status !== 'supported' && caseEntry.status !== 'partial') {
      continue;
    }
    if (matchedBrowserIds.has(object.objectId)) {
      continue;
    }

    const cropPath = await buildBrowserEvidenceCrop({
      outDir,
      referenceMetrics,
      browserObject: object,
      imageCache,
    });

    missing.push({
      chapterIndex: object.chapterIndex,
      blockCaseId: object.blockCaseId,
      featureCaseIds: object.featureCaseIds,
      reason: 'no_canvas_match',
      browserObjectId: object.objectId,
      excerpt: excerptText(object.text || object.visibleText || ''),
      browserCropPath: cropPath,
      browserScreenshotPath: object.screenshotPath,
      domPath: object.domPath,
      status: caseEntry.status,
      notes:
        caseEntry.status === 'partial'
          ? 'Observed in browser but no high-confidence converted node was matched. Case is currently partial.'
          : 'Observed in browser but not converted into RenderNode inventory.',
    });
  }

  return missing.sort((a, b) => a.chapterIndex - b.chapterIndex || a.blockCaseId.localeCompare(b.blockCaseId));
}

async function buildBrowserEvidenceCrop({ outDir, referenceMetrics, browserObject, imageCache }) {
  if (browserObject.rect == null || browserObject.screenshotPath == null) {
    return null;
  }
  const sourcePath = path.join(outDir, 'reference', browserObject.screenshotPath);
  const outputPath = path.join(
    outDir,
    'report_assets',
    'missing_conversions',
    `chapter_${String(browserObject.chapterIndex).padStart(3, '0')}`,
    `${browserObject.objectId.replaceAll(':', '_')}_browser.png`,
  );
  const cropPath = await writeCrop({
    imageCache,
    sourcePath,
    outputPath,
    rect: browserObject.rect,
    devicePixelRatio: referenceMetrics.devicePixelRatio,
  });
  return cropPath == null ? null : path.relative(outDir, cropPath).replaceAll('\\', '/');
}
