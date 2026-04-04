import fs from 'node:fs/promises';
import path from 'node:path';

/**
 * Read book.json from cache directory and resolve chapter XHTML file paths.
 * Respects config.maxChapters to limit the number of chapters processed.
 */
export async function resolveChapterXhtmlPaths(config) {
  const bookJsonPath = path.join(config.cacheDir, 'book.json');
  const bookJson = JSON.parse(await fs.readFile(bookJsonPath, 'utf8'));
  if (!Array.isArray(bookJson.spine)) {
    throw new Error(`Invalid book.json: expected spine to be an array, got ${typeof bookJson.spine}`);
  }
  let spine = bookJson.spine;

  // Sort by index to ensure consistent order
  spine = [...spine].sort((a, b) => a.index - b.index);

  // Apply maxChapters limit
  if (config.maxChapters != null) {
    spine = spine.slice(0, config.maxChapters);
  }

  return spine.map((entry) => {
    // Strip leading '/' from href and join to extractedDir
    const relativePath = entry.href.replace(/^\//, '');
    return path.join(config.extractedDir, relativePath);
  });
}

/**
 * Load chapter JSON files from cache directory.
 * Files are named chapter_0.json, chapter_1.json, etc.
 */
export async function loadChapterJsons(config, chapterCount) {
  const chapterJsons = [];
  for (let i = 0; i < chapterCount; i++) {
    const chapterPath = path.join(config.cacheDir, `chapter_${i}.json`);
    try {
      const content = await fs.readFile(chapterPath, 'utf8');
      chapterJsons.push(JSON.parse(content));
    } catch (err) {
      // Missing chapter file is expected (gap detector handles null); other errors bubble up
      if (err.code === 'ENOENT') {
        chapterJsons.push(null);
      } else {
        throw err;
      }
    }
  }
  return chapterJsons;
}
