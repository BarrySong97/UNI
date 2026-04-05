import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import {
  buildBatchReport,
  discoverEpubs,
  slugify,
} from '../batch_structural_check.mjs';

const caseCatalog = {
  byId: {
    'block.table.colspan': {
      caseId: 'block.table.colspan',
      sourceHtmlTags: ['td', 'th'],
    },
    'inline.superscript': {
      caseId: 'inline.superscript',
      sourceHtmlTags: ['sup'],
    },
  },
};

test('slugify normalizes punctuation and falls back for non-ASCII-only names', () => {
  assert.equal(slugify('The Rust Programming Language!'), 'the-rust-programming-language');
  assert.match(slugify('コンビニ人間'), /^epub-[0-9a-f]+$/);
});

test('discoverEpubs returns sorted epub files and respects recursion', async () => {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'batch-epubs-'));
  const nestedDir = path.join(tempDir, 'nested');
  await fs.mkdir(nestedDir, { recursive: true });
  await fs.writeFile(path.join(tempDir, 'b.epub'), '');
  await fs.writeFile(path.join(tempDir, 'a.epub'), '');
  await fs.writeFile(path.join(nestedDir, 'c.epub'), '');
  await fs.writeFile(path.join(tempDir, 'ignore.txt'), '');

  const relativeDir = path.relative(process.cwd(), tempDir);
  const topLevel = await discoverEpubs(relativeDir, false);
  const recursive = await discoverEpubs(relativeDir, true);

  assert.deepEqual(topLevel.map((value) => path.basename(value)), ['a.epub', 'b.epub']);
  assert.deepEqual(recursive.map((value) => path.basename(value)), ['a.epub', 'b.epub', 'c.epub']);

  await fs.rm(tempDir, { recursive: true, force: true });
});

test('buildBatchReport ranks parser errors before weighted gaps', () => {
  const report = buildBatchReport(
    [
      {
        status: 'ok',
        epubPath: path.join(process.cwd(), 'epubs/linear-algebra.epub'),
        slug: 'linear-algebra',
        structuralGaps: {
          summary: {
            gapScore: 5,
            missingElements: 1,
            featureGaps: 2,
            overConvertedNodes: 0,
          },
          gaps: [
            { type: 'missing_element', blockCaseId: 'block.table.colspan' },
            { type: 'feature_gap', missingFeature: 'inline.superscript' },
            { type: 'feature_gap', missingFeature: 'inline.superscript' },
          ],
        },
      },
      {
        status: 'ok',
        epubPath: path.join(process.cwd(), 'epubs/moby-dick-mo.epub'),
        slug: 'moby-dick-mo',
        structuralGaps: {
          summary: {
            gapScore: 4,
            missingElements: 1,
            featureGaps: 0,
            overConvertedNodes: 1,
          },
          gaps: [
            { type: 'missing_element', blockCaseId: 'block.table.colspan' },
            { type: 'over_converted', renderNodeKind: 'block.table.colspan' },
          ],
        },
      },
      {
        status: 'parser_error',
        epubPath: path.join(process.cwd(), 'epubs/kusamakura.epub'),
        slug: 'kusamakura',
        error: "thread 'main' panicked at 'unknown element: ruby'",
      },
      {
        status: 'ok',
        epubPath: path.join(process.cwd(), 'epubs/clean.epub'),
        slug: 'clean',
        structuralGaps: {
          summary: {
            gapScore: 0,
            missingElements: 0,
            featureGaps: 0,
            overConvertedNodes: 0,
          },
          gaps: [],
        },
      },
    ],
    caseCatalog,
  );

  assert.equal(report.epubsScanned, 4);
  assert.equal(report.epubsWithGaps, 2);
  assert.equal(report.epubsWithParserErrors, 1);
  assert.equal(report.epubsClean, 1);
  assert.equal(report.totalGapScore, 9);
  assert.deepEqual(report.summary, {
    missingElements: 2,
    featureGaps: 2,
    overConvertedNodes: 1,
  });

  assert.equal(report.prioritizedFixList[0].type, 'parser_error');
  assert.equal(report.prioritizedFixList[1].caseId, 'block.table.colspan');
  assert.equal(report.prioritizedFixList[1].impactScore, 16);
  assert.equal(report.prioritizedFixList[2].caseId, 'inline.superscript');
  assert.equal(report.prioritizedFixList[2].impactScore, 2);

  const parserEntry = report.byEpub.find((entry) => entry.status === 'parser_error');
  assert.match(parserEntry?.epub ?? '', /epubs\/kusamakura\.epub$/);
});
