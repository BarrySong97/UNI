import test from 'node:test';
import assert from 'node:assert/strict';

import { alignAnchors } from '../src/diff/align_anchors.mjs';

test('alignAnchors matches exact anchor hashes and reports missing canvas anchors', () => {
  const referenceMetrics = {
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 0,
        anchors: [
          {
            anchorHash: 'aaaa',
            chapterIndex: 0,
            pageIndex: 0,
            order: 0,
            nodeType: 'P',
            normalizedText: 'alpha beta',
            styleSignature: 'node=P|kind=text|weight=400',
            rect: { left: 0, top: 0, width: 100, height: 20 },
            lineCount: 1,
          },
          {
            anchorHash: 'bbbb',
            chapterIndex: 0,
            pageIndex: 0,
            order: 1,
            nodeType: 'P',
            normalizedText: 'missing',
            styleSignature: 'node=P|kind=text|weight=400',
            rect: { left: 0, top: 30, width: 100, height: 20 },
            lineCount: 1,
          },
        ],
      },
    ],
  };

  const canvasMetrics = {
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 0,
        anchors: [
          {
            anchorHash: 'aaaa',
            chapterIndex: 0,
            pageIndex: 0,
            order: 0,
            nodeType: 'P',
            normalizedText: 'alpha beta',
            styleSignature: 'node=P|kind=text|weight=400',
            rect: { left: 1, top: 1, width: 100, height: 20 },
            lineCount: 1,
          },
        ],
      },
    ],
  };

  const result = alignAnchors(referenceMetrics, canvasMetrics);

  assert.equal(result.aligned.length, 1);
  assert.equal(result.diffs.some((diff) => diff.diffType === 'missing-anchor-on-canvas'), true);
});
