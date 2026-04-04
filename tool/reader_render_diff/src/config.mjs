import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_SAMPLE_HINT = 'Project Hail Mary';

export async function resolveConfig(argv) {
  const toolDir = path.dirname(fileURLToPath(import.meta.url));
  const repoRoot = path.resolve(toolDir, '..', '..', '..');
  const epubsDir = path.join(repoRoot, 'epubs');
  const args = parseArgs(argv);

  const viewport = parseViewport(args.viewport ?? '390x844');
  const devicePixelRatio = numberFlag(args.dpr, 2);
  const fontSize = numberFlag(args['font-size'], 18);
  const lineHeight = numberFlag(args['line-height'], 1.6);
  const horizontalPadding = numberFlag(args['page-horizontal-padding'], 24);
  const verticalPadding = numberFlag(args['page-vertical-padding'], 40);
  const paragraphSpacing = numberFlag(args['paragraph-spacing'], 1.0);
  const fullBook = Boolean(args['full-book']);
  const maxChapters = fullBook ? null : limitFlag(args['max-chapters'], 1);
  const maxPagesPerChapter = fullBook
    ? null
    : limitFlag(args['max-pages-per-chapter'], 8);
  const chapterIndices = parseChapterIndices(args.chapters);

  const sampleInfo = await resolveSample({
    epubsDir,
    explicitEpub: args.epub,
    sampleHint: args.sample,
  });

  const slug = slugify(sampleInfo.sampleName ?? path.basename(sampleInfo.epubPath, '.epub'));
  const outDir =
    args.out != null
      ? path.resolve(repoRoot, args.out)
      : path.join(repoRoot, 'build', 'reader_render_diff', slug);

  await fs.mkdir(outDir, { recursive: true });

  return {
    repoRoot,
    epubsDir,
    outDir,
    cacheDir: path.join(outDir, 'cache'),
    inputDir: path.join(outDir, 'input'),
    extractedDir: path.join(outDir, 'input', 'extracted'),
    referenceDir: path.join(outDir, 'reference'),
    canvasDir: path.join(outDir, 'canvas'),
    diffDir: path.join(outDir, 'diff'),
    allowlistPath: path.join(repoRoot, 'tool', 'reader_render_diff', 'allowlist.json'),
    caseCatalogPath: path.join(repoRoot, 'tool', 'reader_render_diff', 'case_catalog.json'),
    viewport,
    devicePixelRatio,
    fullBook,
    maxChapters,
    maxPagesPerChapter,
    chapterIndices,
    epubPath: sampleInfo.epubPath,
    sampleName: sampleInfo.sampleName,
    readerPreferences: {
      baseFontSizePx: fontSize,
      fontFamily: args['font-family'] ?? 'Georgia',
      pageHorizontalPaddingPx: horizontalPadding,
      pageVerticalPaddingPx: verticalPadding,
      lineHeightMultiplier: lineHeight,
      paragraphSpacingMultiplier: paragraphSpacing,
      theme: args.theme ?? 'light',
    },
  };
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }
    const key = token.slice(2);
    const next = argv[index + 1];
    if (next == null || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    index += 1;
  }
  return args;
}

function parseViewport(input) {
  const match = /^(\d+)x(\d+)$/i.exec(input);
  if (match == null) {
    throw new Error(`Invalid --viewport value "${input}". Expected WIDTHxHEIGHT.`);
  }
  return {
    width: Number(match[1]),
    height: Number(match[2]),
  };
}

function parseChapterIndices(input) {
  if (input == null || input === '') {
    return null;
  }
  return input
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
    .map((value) => {
      const parsed = Number.parseInt(value, 10);
      if (Number.isNaN(parsed)) {
        throw new Error(`Invalid chapter index "${value}" in --chapters.`);
      }
      return parsed;
    });
}

function numberFlag(input, fallback) {
  if (input == null) {
    return fallback;
  }
  const parsed = Number(input);
  if (Number.isNaN(parsed)) {
    throw new Error(`Expected numeric flag, received "${input}".`);
  }
  return parsed;
}

function limitFlag(input, fallback) {
  if (input == null) {
    return fallback;
  }
  if (typeof input === 'string' && input.toLowerCase() === 'all') {
    return null;
  }
  const parsed = Math.trunc(numberFlag(input, fallback));
  if (parsed <= 0) {
    throw new Error(`Expected a positive integer or "all", received "${input}".`);
  }
  return parsed;
}

async function resolveSample({ epubsDir, explicitEpub, sampleHint }) {
  if (explicitEpub != null) {
    const epubPath = path.resolve(explicitEpub);
    return {
      epubPath,
      sampleName: path.basename(epubPath),
    };
  }

  const dirEntries = await fs.readdir(epubsDir, { withFileTypes: true }).catch(() => null);
  if (dirEntries == null) {
    throw new Error(`Sample EPUB directory not found: ${epubsDir}`);
  }

  const epubFiles = dirEntries
    .filter((entry) => entry.isFile() && /\.epub$/i.test(entry.name))
    .map((entry) => ({
      fileName: entry.name,
      absolutePath: path.join(epubsDir, entry.name),
    }));

  if (epubFiles.length === 0) {
    throw new Error(`No EPUB files found under ${epubsDir}`);
  }

  const hint = sampleHint ?? DEFAULT_SAMPLE_HINT;
  const matches = epubFiles.filter(({ fileName }) =>
    fileName.toLowerCase().includes(hint.toLowerCase()),
  );

  if (matches.length === 1) {
    return {
      epubPath: matches[0].absolutePath,
      sampleName: matches[0].fileName,
    };
  }

  if (matches.length === 0 && sampleHint != null) {
    throw new Error(`No EPUB sample matched "${sampleHint}" under ${epubsDir}`);
  }

  if (matches.length > 1) {
    throw new Error(
      `Multiple EPUB samples matched "${hint}": ${matches.map((match) => match.fileName).join(', ')}`,
    );
  }

  const fallback = epubFiles.find(({ fileName }) =>
    fileName.toLowerCase().includes(DEFAULT_SAMPLE_HINT.toLowerCase()),
  );
  if (fallback == null) {
    throw new Error(
      `Default smoke sample "${DEFAULT_SAMPLE_HINT}" was not found under ${epubsDir}`,
    );
  }

  return {
    epubPath: fallback.absolutePath,
    sampleName: fallback.fileName,
  };
}

function slugify(value) {
  return value
    .normalize('NFKD')
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/[\s_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();
}
