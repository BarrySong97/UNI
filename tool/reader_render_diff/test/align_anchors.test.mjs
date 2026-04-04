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

test('alignAnchors falls back to substantial text overlap when fragment text differs', () => {
  const referenceMetrics = {
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 2,
        anchors: [
          {
            anchorHash: 'ref-fragment',
            chapterIndex: 0,
            pageIndex: 2,
            order: 0,
            nodeType: 'P',
            normalizedText: 'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda',
            styleSignature: 'node=P|kind=text|weight=400',
            rect: { left: 0, top: 0, width: 100, height: 20 },
            lineCount: 3,
          },
        ],
      },
    ],
  };

  const canvasMetrics = {
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 4,
        anchors: [
          {
            anchorHash: 'canvas-fragment',
            chapterIndex: 0,
            pageIndex: 4,
            order: 0,
            nodeType: 'ParagraphNode',
            normalizedText: 'gamma delta epsilon zeta eta theta',
            styleSignature: 'node=ParagraphNode|kind=paragraph|weight=400',
            rect: { left: 5, top: 6, width: 90, height: 24 },
            lineCount: 2,
          },
        ],
      },
    ],
  };

  const result = alignAnchors(referenceMetrics, canvasMetrics);

  assert.equal(result.aligned.length, 1);
  assert.equal(result.aligned[0].canvas.pageIndex, 4);
});
