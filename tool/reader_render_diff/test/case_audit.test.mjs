import test from 'node:test';
import assert from 'node:assert/strict';

import { buildBrowserObjects } from '../src/cases/classify_browser_object.mjs';
import { buildCanvasObjects } from '../src/cases/classify_canvas_object.mjs';
import { buildCaseInventory } from '../src/audit/build_case_inventory.mjs';
import { findMissingConversions } from '../src/audit/find_missing_conversions.mjs';
import { matchContentObjects } from '../src/report/build_matched_screenshot_pairs.mjs';

const caseCatalog = {
  entries: [
    { caseId: 'block.paragraph', layer: 'block', status: 'supported' },
    { caseId: 'block.image', layer: 'block', status: 'partial' },
    { caseId: 'block.horizontal_rule', layer: 'block', status: 'supported' },
    { caseId: 'inline.bold', layer: 'inline', status: 'supported' },
    { caseId: 'inline.link', layer: 'inline', status: 'supported' },
    { caseId: 'layout.align.left', layer: 'layout', status: 'supported' },
    { caseId: 'special.flattened_container', layer: 'special', status: 'ignored_by_design' },
  ],
  byId: {
    'block.paragraph': { caseId: 'block.paragraph', layer: 'block', status: 'supported' },
    'block.image': { caseId: 'block.image', layer: 'block', status: 'partial' },
    'block.horizontal_rule': { caseId: 'block.horizontal_rule', layer: 'block', status: 'supported' },
    'inline.bold': { caseId: 'inline.bold', layer: 'inline', status: 'supported' },
    'inline.link': { caseId: 'inline.link', layer: 'inline', status: 'supported' },
    'layout.align.left': { caseId: 'layout.align.left', layer: 'layout', status: 'supported' },
    'special.flattened_container': {
      caseId: 'special.flattened_container',
      layer: 'special',
      status: 'ignored_by_design',
    },
  },
};

test('browser objects are classified into block and feature cases', () => {
  const referenceMetrics = {
    chapterSpecialCases: [],
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 0,
        screenshotPath: 'screenshots/ch0/p0.png',
        blocks: [
          {
            order: 0,
            tagName: 'p',
            domPath: 'html>body>p:nth-of-type(1)',
            fullText: 'Alpha beta gamma',
            visibleText: 'Alpha beta gamma',
            rect: { left: 10, top: 20, width: 120, height: 30 },
            computedStyleSummary: {
              textAlign: 'left',
              colorHex: 'ff111111',
            },
            featureFlags: {
              bold: true,
              link: true,
            },
          },
        ],
      },
    ],
  };

  const { browserObjects } = buildBrowserObjects(referenceMetrics, caseCatalog);
  assert.equal(browserObjects.length, 1);
  assert.equal(browserObjects[0].blockCaseId, 'block.paragraph');
  assert.deepEqual(browserObjects[0].featureCaseIds, [
    'inline.bold',
    'inline.link',
    'layout.align.left',
    'layout.text_color',
  ]);
  assert.equal(browserObjects[0].matchEligible, true);
});

test('canvas objects preserve inventory and first appearance mapping', () => {
  const canvasMetrics = {
    nodeInventory: [
      {
        objectId: 'canvas:0:0',
        chapterIndex: 0,
        nodeOrdinal: 0,
        nodePath: 'chapter[0].nodes[0]',
        renderNodeKind: 'ParagraphNode',
        blockCaseHint: 'block.paragraph',
        featureCaseHints: ['layout.align.left'],
        observedCaseHints: ['block.paragraph', 'layout.align.left'],
        rawNodeSummary: { align: 'left' },
        text: 'Alpha beta gamma',
        normalizedText: 'Alpha beta gamma',
      },
    ],
    pages: [
      {
        chapterIndex: 0,
        pageIndex: 0,
        screenshotPath: 'screenshots/ch0/p0.png',
        blocks: [
          {
            objectId: 'canvas:0:0',
            nodePath: 'chapter[0].nodes[0]',
            order: 0,
            rect: { left: 8, top: 18, width: 124, height: 32 },
          },
        ],
      },
    ],
  };

  const canvasObjects = buildCanvasObjects(canvasMetrics, caseCatalog);
  assert.equal(canvasObjects.length, 1);
  assert.equal(canvasObjects[0].blockCaseId, 'block.paragraph');
  assert.equal(canvasObjects[0].screenshotPath, 'screenshots/ch0/p0.png');
  assert.equal(canvasObjects[0].rect.width, 124);
});

test('ambiguous repeated low-confidence matches are discarded', () => {
  const browserObjects = [
    {
      objectId: 'browser:0:0',
      chapterIndex: 0,
      ordinal: 0,
      blockCaseId: 'block.paragraph',
      featureCaseIds: [],
      normalizedText: 'Alpha beta gamma',
      canonicalText: 'alphabetagamma',
      matchEligible: true,
      text: 'Alpha beta gamma',
    },
    {
      objectId: 'browser:0:1',
      chapterIndex: 0,
      ordinal: 0,
      blockCaseId: 'block.paragraph',
      featureCaseIds: [],
      normalizedText: 'Alpha beta gamma',
      canonicalText: 'alphabetagamma',
      matchEligible: true,
      text: 'Alpha beta gamma',
    },
  ];
  const canvasObjects = [
    {
      objectId: 'canvas:0:0',
      chapterIndex: 0,
      ordinal: 0,
      blockCaseId: 'block.paragraph',
      featureCaseIds: [],
      normalizedText: 'Alpha beta gamma',
      canonicalText: 'alphabetagamma',
      matchEligible: true,
      text: 'Alpha beta gamma',
      rawNodeSummary: { align: 'left' },
    },
  ];

  const matches = matchContentObjects({ browserObjects, canvasObjects });
  assert.deepEqual(matches, []);
});

test('missing conversions are reported only for unmatched supported or partial browser objects', async () => {
  const browserObjects = [
    {
      objectId: 'browser:0:0',
      chapterIndex: 0,
      blockCaseId: 'block.paragraph',
      featureCaseIds: [],
      status: 'supported',
      text: 'Alpha beta gamma',
      visibleText: 'Alpha beta gamma',
      screenshotPath: null,
      rect: null,
      domPath: 'html>body>p:nth-of-type(1)',
    },
    {
      objectId: 'browser:0:1',
      chapterIndex: 0,
      blockCaseId: 'block.image',
      featureCaseIds: [],
      status: 'partial',
      text: 'Figure',
      visibleText: 'Figure',
      screenshotPath: null,
      rect: null,
      domPath: 'html>body>img:nth-of-type(1)',
    },
  ];

  const missing = await findMissingConversions({
    outDir: '/tmp',
    referenceMetrics: { devicePixelRatio: 2 },
    browserObjects,
    matchedObjects: [{ browserObjectId: 'browser:0:1' }],
    caseCatalog,
  });

  assert.equal(missing.length, 1);
  assert.equal(missing[0].blockCaseId, 'block.paragraph');
});

test('case inventory aggregates browser, canvas, missing, and ignored counts', () => {
  const inventory = buildCaseInventory({
    caseCatalog,
    browserObjects: [
      {
        chapterIndex: 0,
        observedCaseIds: ['block.paragraph', 'inline.bold'],
      },
    ],
    canvasObjects: [
      {
        chapterIndex: 0,
        observedCaseIds: ['block.paragraph'],
      },
    ],
    missingConversions: [
      {
        chapterIndex: 0,
        blockCaseId: 'block.paragraph',
        featureCaseIds: ['inline.bold'],
      },
    ],
    ignoredCaseCounts: {
      'special.flattened_container': 2,
    },
  });

  const paragraph = inventory.find((item) => item.caseId === 'block.paragraph');
  const special = inventory.find(
    (item) => item.caseId === 'special.flattened_container',
  );
  assert.equal(paragraph?.browserCount, 1);
  assert.equal(paragraph?.canvasCount, 1);
  assert.equal(paragraph?.missingCount, 1);
  assert.equal(special?.ignoredCount, 2);
});
