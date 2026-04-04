import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

import { resolveConfig } from '../src/config.mjs';
import { resolveChapterXhtmlPaths, loadChapterJsons } from '../src/structural/resolve_chapters.mjs';

// ---------------------------------------------------------------------------
// Config parsing: --structural-check flag
// ---------------------------------------------------------------------------

test('resolveConfig sets structuralCheck=false when flag is absent', async () => {
  const config = await resolveConfig(['--epub', 'epubs/dummy.epub']);
  assert.equal(config.structuralCheck, false);
});

test('resolveConfig sets structuralCheck=true when flag is present', async () => {
  const config = await resolveConfig(['--structural-check', '--epub', 'epubs/dummy.epub']);
  assert.equal(config.structuralCheck, true);
});

test('resolveConfig preserves maxChapters with --structural-check', async () => {
  const config = await resolveConfig([
    '--structural-check',
    '--epub', 'epubs/dummy.epub',
    '--max-chapters', '5',
  ]);
  assert.equal(config.structuralCheck, true);
  assert.equal(config.maxChapters, 5);
});

test('resolveConfig allows --full-book with --structural-check', async () => {
  const config = await resolveConfig([
    '--structural-check',
    '--full-book',
    '--epub', 'epubs/dummy.epub',
  ]);
  assert.equal(config.structuralCheck, true);
  assert.equal(config.fullBook, true);
  assert.equal(config.maxChapters, null);
});

// ---------------------------------------------------------------------------
// resolveChapterXhtmlPaths: book.json spine → file paths
// ---------------------------------------------------------------------------

test('resolveChapterXhtmlPaths maps spine hrefs to extracted dir paths', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  const extractedDir = path.join(tmpDir, 'extracted');
  await fs.mkdir(cacheDir, { recursive: true });
  await fs.mkdir(extractedDir, { recursive: true });

  const bookJson = {
    spine: [
      { href: '/OEBPS/cover.xhtml', index: 0 },
      { href: '/OEBPS/chapter1.xhtml', index: 1 },
      { href: '/OEBPS/chapter2.xhtml', index: 2 },
    ],
  };
  await fs.writeFile(path.join(cacheDir, 'book.json'), JSON.stringify(bookJson));

  const config = { cacheDir, extractedDir, maxChapters: null };
  const paths = await resolveChapterXhtmlPaths(config);

  assert.equal(paths.length, 3);
  assert.equal(paths[0], path.join(extractedDir, 'OEBPS', 'cover.xhtml'));
  assert.equal(paths[1], path.join(extractedDir, 'OEBPS', 'chapter1.xhtml'));
  assert.equal(paths[2], path.join(extractedDir, 'OEBPS', 'chapter2.xhtml'));

  await fs.rm(tmpDir, { recursive: true });
});

test('resolveChapterXhtmlPaths respects maxChapters limit', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  const extractedDir = path.join(tmpDir, 'extracted');
  await fs.mkdir(cacheDir, { recursive: true });

  const bookJson = {
    spine: [
      { href: '/OEBPS/ch0.xhtml', index: 0 },
      { href: '/OEBPS/ch1.xhtml', index: 1 },
      { href: '/OEBPS/ch2.xhtml', index: 2 },
      { href: '/OEBPS/ch3.xhtml', index: 3 },
    ],
  };
  await fs.writeFile(path.join(cacheDir, 'book.json'), JSON.stringify(bookJson));

  const config = { cacheDir, extractedDir, maxChapters: 2 };
  const paths = await resolveChapterXhtmlPaths(config);

  assert.equal(paths.length, 2);
  assert.equal(paths[0], path.join(extractedDir, 'OEBPS', 'ch0.xhtml'));
  assert.equal(paths[1], path.join(extractedDir, 'OEBPS', 'ch1.xhtml'));

  await fs.rm(tmpDir, { recursive: true });
});

test('resolveChapterXhtmlPaths sorts spine by index', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  const extractedDir = path.join(tmpDir, 'extracted');
  await fs.mkdir(cacheDir, { recursive: true });

  // Spine entries out of order
  const bookJson = {
    spine: [
      { href: '/OEBPS/ch2.xhtml', index: 2 },
      { href: '/OEBPS/ch0.xhtml', index: 0 },
      { href: '/OEBPS/ch1.xhtml', index: 1 },
    ],
  };
  await fs.writeFile(path.join(cacheDir, 'book.json'), JSON.stringify(bookJson));

  const config = { cacheDir, extractedDir, maxChapters: null };
  const paths = await resolveChapterXhtmlPaths(config);

  assert.equal(paths[0], path.join(extractedDir, 'OEBPS', 'ch0.xhtml'));
  assert.equal(paths[1], path.join(extractedDir, 'OEBPS', 'ch1.xhtml'));
  assert.equal(paths[2], path.join(extractedDir, 'OEBPS', 'ch2.xhtml'));

  await fs.rm(tmpDir, { recursive: true });
});

test('resolveChapterXhtmlPaths handles hrefs without leading slash', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  const extractedDir = path.join(tmpDir, 'extracted');
  await fs.mkdir(cacheDir, { recursive: true });

  const bookJson = {
    spine: [
      { href: 'content/chapter1.xhtml', index: 0 },
    ],
  };
  await fs.writeFile(path.join(cacheDir, 'book.json'), JSON.stringify(bookJson));

  const config = { cacheDir, extractedDir, maxChapters: null };
  const paths = await resolveChapterXhtmlPaths(config);

  assert.equal(paths.length, 1);
  assert.equal(paths[0], path.join(extractedDir, 'content', 'chapter1.xhtml'));

  await fs.rm(tmpDir, { recursive: true });
});

// ---------------------------------------------------------------------------
// loadChapterJsons: load chapter_N.json from cache
// ---------------------------------------------------------------------------

test('loadChapterJsons loads existing chapter files', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  await fs.mkdir(cacheDir, { recursive: true });

  const ch0 = { index: 0, title: 'Cover', href: '/OEBPS/cover.xhtml', nodes: [] };
  const ch1 = { index: 1, title: 'Chapter 1', href: '/OEBPS/ch1.xhtml', nodes: [{ type: 'Paragraph', children: [] }] };
  await fs.writeFile(path.join(cacheDir, 'chapter_0.json'), JSON.stringify(ch0));
  await fs.writeFile(path.join(cacheDir, 'chapter_1.json'), JSON.stringify(ch1));

  const config = { cacheDir };
  const result = await loadChapterJsons(config, 2);

  assert.equal(result.length, 2);
  assert.deepEqual(result[0], ch0);
  assert.deepEqual(result[1], ch1);

  await fs.rm(tmpDir, { recursive: true });
});

test('loadChapterJsons returns null for missing chapter files', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  await fs.mkdir(cacheDir, { recursive: true });

  // Only chapter_0 exists, chapter_1 does not
  const ch0 = { index: 0, title: 'Cover', href: '/cover.xhtml', nodes: [] };
  await fs.writeFile(path.join(cacheDir, 'chapter_0.json'), JSON.stringify(ch0));

  const config = { cacheDir };
  const result = await loadChapterJsons(config, 3);

  assert.equal(result.length, 3);
  assert.deepEqual(result[0], ch0);
  assert.equal(result[1], null);
  assert.equal(result[2], null);

  await fs.rm(tmpDir, { recursive: true });
});

test('loadChapterJsons handles zero chapters', async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'sc-test-'));
  const cacheDir = path.join(tmpDir, 'cache');
  await fs.mkdir(cacheDir, { recursive: true });

  const config = { cacheDir };
  const result = await loadChapterJsons(config, 0);

  assert.equal(result.length, 0);

  await fs.rm(tmpDir, { recursive: true });
});
