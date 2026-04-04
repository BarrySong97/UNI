import fs from 'node:fs/promises';
import path from 'node:path';

import { PNG } from 'pngjs';

export async function buildAnchorScreenshotPairs({
  outDir,
  referenceMetrics,
  canvasMetrics,
  alignedAnchors,
}) {
  const outputRoot = path.join(outDir, 'report_assets', 'anchor_pairs');
  await fs.mkdir(outputRoot, { recursive: true });

  const referencePages = new Map(
    referenceMetrics.pages.map((page) => [pageKey(page.chapterIndex, page.pageIndex), page]),
  );
  const canvasPages = new Map(
    canvasMetrics.pages.map((page) => [pageKey(page.chapterIndex, page.pageIndex), page]),
  );
  const imageCache = new Map();

  const pairs = [];
  const seenKeys = new Set();
  const sortedAnchors = [...alignedAnchors].sort(
    (a, b) =>
      a.chapterIndex - b.chapterIndex ||
      a.reference.pageIndex - b.reference.pageIndex ||
      a.reference.order - b.reference.order ||
      a.canvas.pageIndex - b.canvas.pageIndex ||
      a.canvas.order - b.canvas.order,
  );

  for (let index = 0; index < sortedAnchors.length; index += 1) {
    const aligned = sortedAnchors[index];
    const match = classifyTextMatch(
      aligned.reference.normalizedText,
      aligned.canvas.normalizedText,
    );
    if (match == null) {
      continue;
    }

    const referencePage = referencePages.get(
      pageKey(aligned.reference.chapterIndex, aligned.reference.pageIndex),
    );
    const canvasPage = canvasPages.get(pageKey(aligned.canvas.chapterIndex, aligned.canvas.pageIndex));
    if (referencePage == null || canvasPage == null) {
      continue;
    }

    const excerpt = buildExcerpt(
      aligned.reference.normalizedText || aligned.canvas.normalizedText || '',
    );
    if (excerpt === '') {
      continue;
    }
    const dedupeKey = `${aligned.chapterIndex}:${match.canonical}`;
    if (seenKeys.has(dedupeKey)) {
      continue;
    }

    const referenceCropPath = await writeCrop({
      imageCache,
      sourcePath: path.join(outDir, 'reference', referencePage.screenshotPath),
      outputPath: path.join(
        outputRoot,
        `chapter_${String(aligned.chapterIndex).padStart(3, '0')}`,
        `${String(index).padStart(5, '0')}_${aligned.anchorHash}_reference.png`,
      ),
      rect: aligned.reference.rect,
      devicePixelRatio: referenceMetrics.devicePixelRatio,
    });
    const canvasCropPath = await writeCrop({
      imageCache,
      sourcePath: path.join(outDir, 'canvas', canvasPage.screenshotPath),
      outputPath: path.join(
        outputRoot,
        `chapter_${String(aligned.chapterIndex).padStart(3, '0')}`,
        `${String(index).padStart(5, '0')}_${aligned.anchorHash}_canvas.png`,
      ),
      rect: aligned.canvas.rect,
      devicePixelRatio: canvasMetrics.devicePixelRatio,
    });
    if (referenceCropPath == null || canvasCropPath == null) {
      continue;
    }

    seenKeys.add(dedupeKey);
    pairs.push({
      chapterIndex: aligned.chapterIndex,
      anchorHash: aligned.anchorHash,
      matchKind: match.kind,
      excerpt,
      fullText: aligned.reference.text || aligned.canvas.text || excerpt,
      referencePageIndex: aligned.reference.pageIndex,
      canvasPageIndex: aligned.canvas.pageIndex,
      referenceCropPath: path.relative(outDir, referenceCropPath).replaceAll('\\', '/'),
      canvasCropPath: path.relative(outDir, canvasCropPath).replaceAll('\\', '/'),
    });
  }

  return pairs;
}

async function writeCrop({ imageCache, sourcePath, outputPath, rect, devicePixelRatio }) {
  const image = await readPng(imageCache, sourcePath);
  if (image == null) {
    return null;
  }

  const cropRect = computeCropRect({
    image,
    rect,
    scale: devicePixelRatio || 1,
    padding: 16,
  });
  if (cropRect == null) {
    return null;
  }

  const cropped = cropImage(image, cropRect);
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, PNG.sync.write(cropped));
  return outputPath;
}

async function readPng(imageCache, filePath) {
  if (imageCache.has(filePath)) {
    return imageCache.get(filePath);
  }
  const bytes = await fs.readFile(filePath).catch(() => null);
  if (bytes == null) {
    return null;
  }
  const image = PNG.sync.read(bytes);
  imageCache.set(filePath, image);
  return image;
}

function computeCropRect({ image, rect, scale, padding }) {
  const left = Math.max(0, Math.floor(rect.left * scale) - padding);
  const top = Math.max(0, Math.floor(rect.top * scale) - padding);
  const right = Math.min(
    image.width,
    Math.ceil((rect.left + rect.width) * scale) + padding,
  );
  const bottom = Math.min(
    image.height,
    Math.ceil((rect.top + rect.height) * scale) + padding,
  );
  if (right <= left || bottom <= top) {
    return null;
  }
  return {
    left,
    top,
    width: right - left,
    height: bottom - top,
  };
}

function cropImage(image, cropRect) {
  const cropped = new PNG({ width: cropRect.width, height: cropRect.height });
  for (let y = 0; y < cropRect.height; y += 1) {
    const sourceStart =
      ((cropRect.top + y) * image.width + cropRect.left) * 4;
    const sourceEnd = sourceStart + cropRect.width * 4;
    const targetStart = y * cropRect.width * 4;
    image.data.copy(cropped.data, targetStart, sourceStart, sourceEnd);
  }
  return cropped;
}

function buildExcerpt(text) {
  const normalized = String(text || '').replace(/\s+/g, ' ').trim();
  if (normalized.length <= 180) {
    return normalized;
  }
  return `${normalized.slice(0, 177)}...`;
}

function classifyTextMatch(referenceText, canvasText) {
  const referenceNormalized = normalizeForComparison(referenceText);
  const canvasNormalized = normalizeForComparison(canvasText);
  if (!hasEnoughSignal(referenceNormalized) || !hasEnoughSignal(canvasNormalized)) {
    return null;
  }

  if (referenceNormalized === canvasNormalized) {
    return {
      kind: 'exact',
      canonical: canonicalize(referenceNormalized),
    };
  }

  const referenceCanonical = canonicalize(referenceNormalized);
  const canvasCanonical = canonicalize(canvasNormalized);
  if (!referenceCanonical || !canvasCanonical) {
    return null;
  }

  if (referenceCanonical === canvasCanonical) {
    return {
      kind: 'canonical-exact',
      canonical: referenceCanonical,
    };
  }

  const shorterLength = Math.min(referenceCanonical.length, canvasCanonical.length);
  const longerLength = Math.max(referenceCanonical.length, canvasCanonical.length);
  if (
    shorterLength >= 48 &&
    longerLength > 0 &&
    (referenceCanonical.includes(canvasCanonical) || canvasCanonical.includes(referenceCanonical)) &&
    shorterLength / longerLength >= 0.6
  ) {
    return {
      kind: 'containment',
      canonical:
        referenceCanonical.length <= canvasCanonical.length
          ? referenceCanonical
          : canvasCanonical,
    };
  }

  return null;
}

function normalizeForComparison(text) {
  return String(text || '').replace(/\s+/g, ' ').trim();
}

function canonicalize(text) {
  return normalizeForComparison(text).replace(/[\s"'‘’“”.,;:!?()[\]{}-]+/g, '').toLowerCase();
}

function hasEnoughSignal(text) {
  if (!text) {
    return false;
  }
  const wordCount = text.split(/\s+/).filter(Boolean).length;
  const alphaCount = [...text].filter((char) => /\p{Letter}|\p{Number}/u.test(char)).length;
  return wordCount >= 2 || alphaCount >= 12;
}

function pageKey(chapterIndex, pageIndex) {
  return `${chapterIndex}:${pageIndex}`;
}
