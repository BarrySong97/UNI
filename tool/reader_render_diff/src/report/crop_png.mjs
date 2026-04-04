import fs from 'node:fs/promises';
import path from 'node:path';

import { PNG } from 'pngjs';

export async function writeCrop({
  imageCache,
  sourcePath,
  outputPath,
  rect,
  devicePixelRatio,
  padding = 16,
}) {
  if (rect == null) {
    return null;
  }
  const image = await readPng(imageCache, sourcePath);
  if (image == null) {
    return null;
  }

  const cropRect = computeCropRect({
    image,
    rect,
    scale: devicePixelRatio || 1,
    padding,
  });
  if (cropRect == null) {
    return null;
  }

  const cropped = cropImage(image, cropRect);
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, PNG.sync.write(cropped));
  return outputPath;
}

export async function readPng(imageCache, filePath) {
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
  const right = Math.min(image.width, Math.ceil((rect.left + rect.width) * scale) + padding);
  const bottom = Math.min(image.height, Math.ceil((rect.top + rect.height) * scale) + padding);
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
    const sourceStart = ((cropRect.top + y) * image.width + cropRect.left) * 4;
    const sourceEnd = sourceStart + cropRect.width * 4;
    const targetStart = y * cropRect.width * 4;
    image.data.copy(cropped.data, targetStart, sourceStart, sourceEnd);
  }
  return cropped;
}
