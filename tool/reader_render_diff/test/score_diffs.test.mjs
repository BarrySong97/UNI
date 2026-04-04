import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import { PNG } from 'pngjs';

import { scoreDiffs } from '../src/diff/score_diffs.mjs';

test('scoreDiffs honors allowlist entries and produces diff artifacts', async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'reader-render-diff-'));
  const referenceDir = path.join(tempDir, 'reference', 'screenshots', 'chapter_000');
  const canvasDir = path.join(tempDir, 'canvas', 'screenshots', 'chapter_000');
  const diffDir = path.join(tempDir, 'diff');
  await fs.mkdir(referenceDir, { recursive: true });
  await fs.mkdir(canvasDir, { recursive: true });

  const png = new PNG({ width: 1, height: 1 });
  png.data[0] = 255;
  png.data[1] = 255;
  png.data[2] = 255;
  png.data[3] = 255;
  const bytes = PNG.sync.write(png);
  await fs.writeFile(path.join(referenceDir, 'page_000.png'), bytes);
  await fs.writeFile(path.join(canvasDir, 'page_000.png'), bytes);

  const referenceMetrics = {
    chapterPageCounts: {
      '0': 1,
      '1': 0,
    },
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 0,
        screenshotPath: path.join('screenshots', 'chapter_000', 'page_000.png'),
        normalizedText: 'alpha beta',
        blocks: [],
        anchors: [],
      },
    ],
  };
  const canvasMetrics = {
    chapterPageCounts: {
      '0': 2,
      '1': 1,
    },
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 0,
        screenshotPath: path.join('screenshots', 'chapter_000', 'page_000.png'),
        normalizedText: 'alpha beta',
        blocks: [],
        anchors: [],
      },
      {
        chapterIndex: 1,
        pageIndex: 0,
        screenshotPath: path.join('screenshots', 'chapter_000', 'page_000.png'),
        normalizedText: 'gamma delta',
        blocks: [],
        anchors: [],
      },
    ],
  };

  const result = await scoreDiffs({
    referenceMetrics,
    canvasMetrics,
    alignedAnchors: [],
    anchorDiffs: [
      {
        scope: 'anchor',
        diffType: 'missing-anchor-on-canvas',
        chapterIndex: 0,
        pageIndex: 0,
        anchorHash: 'abc123',
        severity: 0.9,
      },
    ],
    allowlist: {
      entries: [
        {
          diffType: 'missing-anchor-on-canvas',
          chapterIndex: 0,
          anchorHash: 'abc123',
          note: 'Expected temporary mismatch',
        },
      ],
    },
    diffDir,
    outDir: tempDir,
  });

  assert.equal(result.allowlistHits.length, 1);
  assert.equal(typeof result.visualDistance, 'number');
  assert.equal(result.anchorDiffs[0].allowlisted, true);
  assert.equal(result.pageRanking.length, 1);
  assert.equal(result.unmatchedPageRanking.length, 1);
  assert.equal(result.unmatchedPageRanking[0].diffType, 'missing-page');
  assert.deepEqual(result.chapterRanking[0], {
    chapterIndex: 1,
    severity: 1,
    count: 1,
    matchedPageCount: 0,
    unmatchedPageCount: 1,
    anchorDiffCount: 0,
    referencePageCount: 0,
    canvasPageCount: 1,
  });
  await fs.access(path.join(diffDir, 'pages', 'chapter_000', 'page_000.png'));
});
