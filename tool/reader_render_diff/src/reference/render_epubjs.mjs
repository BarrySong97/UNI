import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';

import { chromium } from 'playwright';

import { buildReferencePageMetric } from './extract_metrics.mjs';

export async function renderReferenceArtifacts(config) {
  await fs.mkdir(config.referenceDir, { recursive: true });
  const screenshotsDir = path.join(config.referenceDir, 'screenshots');
  await fs.mkdir(screenshotsDir, { recursive: true });

  const server = await createServer({
    epubPath: config.extractedDir,
    toolRoot: path.join(config.repoRoot, 'tool', 'reader_render_diff'),
  });

  const browser = await chromium.launch({ headless: true });

  try {
    const page = await browser.newPage({
      viewport: {
        width: config.viewport.width,
        height: config.viewport.height,
      },
      deviceScaleFactor: config.devicePixelRatio,
    });

    await page.goto(`${server.origin}/index.html`, { waitUntil: 'load' });
    await page.evaluate(
      async ({ epubUrl, width, height, preferences }) => {
        await window.renderHarness.init({
          epubUrl,
          width,
          height,
          preferences,
        });
      },
      {
        epubUrl: `${server.origin}/book/${config.opfPath}`,
        width: config.viewport.width,
        height: config.viewport.height,
        preferences: config.readerPreferences,
      },
    );

    const chapterCount = await page.evaluate(() => window.renderHarness.chapterCount());
    const chapterIndices = resolveChapterIndices(chapterCount, config);

    const pageMetrics = [];
    const chapterPageCounts = {};

    for (const chapterIndex of chapterIndices) {
      let current = await page.evaluate(
        async (index) => window.renderHarness.displayChapter(index),
        chapterIndex,
      );
      let capturedPages = 0;
      chapterPageCounts[String(chapterIndex)] = 0;

      while (
        current != null &&
        current.chapterIndex === chapterIndex &&
        capturedPages < config.maxPagesPerChapter
      ) {
        const chapterDir = path.join(
          screenshotsDir,
          `chapter_${String(chapterIndex).padStart(3, '0')}`,
        );
        await fs.mkdir(chapterDir, { recursive: true });
        const fileName = `page_${String(current.pageIndex).padStart(3, '0')}.png`;
        const absolutePath = path.join(chapterDir, fileName);
        const relativePath = path.relative(config.referenceDir, absolutePath);

        await page.locator('#viewer').screenshot({ path: absolutePath });
        pageMetrics.push(buildReferencePageMetric(current, relativePath));
        chapterPageCounts[String(chapterIndex)] += 1;
        capturedPages += 1;

        const next = await page.evaluate(() => window.renderHarness.nextPage());
        if (
          next == null ||
          next.chapterIndex !== chapterIndex ||
          next.locationKey === current.locationKey
        ) {
          break;
        }
        current = next;
      }
    }

    const metrics = {
      engine: 'reference',
      epubPath: config.epubPath,
      sampleName: config.sampleName,
      viewportWidth: config.viewport.width,
      viewportHeight: config.viewport.height,
      devicePixelRatio: config.devicePixelRatio,
      pages: pageMetrics,
      chapterPageCounts,
    };

    await fs.writeFile(
      path.join(config.referenceDir, 'metrics.json'),
      JSON.stringify(metrics, null, 2),
    );
    return metrics;
  } finally {
    await browser.close();
    await server.close();
  }
}

function resolveChapterIndices(totalCount, config) {
  if (config.chapterIndices != null && config.chapterIndices.length > 0) {
    return config.chapterIndices;
  }
  return Array.from({ length: Math.min(totalCount, config.maxChapters) }, (_, index) => index);
}

async function createServer({ epubPath, toolRoot }) {
  const html = buildHarnessHtml();
  const server = http.createServer(async (request, response) => {
    if (request.url === '/index.html' || request.url === '/') {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(html);
      return;
    }

    if (request.url?.startsWith('/book/')) {
      const relativePath = decodeURIComponent(request.url.replace(/^\/book\//, ''));
      const filePath = path.join(epubPath, relativePath);
      const bytes = await fs.readFile(filePath).catch(() => null);
      if (bytes == null) {
        response.writeHead(404);
        response.end('Not found');
        return;
      }
      response.writeHead(200, { 'content-type': guessContentType(filePath) });
      response.end(bytes);
      return;
    }

    if (request.url?.startsWith('/node_modules/')) {
      const filePath = path.join(toolRoot, request.url.replace(/^\//, ''));
      const bytes = await fs.readFile(filePath);
      response.writeHead(200, {
        'content-type': guessContentType(filePath),
      });
      response.end(bytes);
      return;
    }

    response.writeHead(404);
    response.end('Not found');
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const origin = `http://127.0.0.1:${address.port}`;

  return {
    origin,
    close: () => new Promise((resolve, reject) => server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    })),
  };
}

function guessContentType(filePath) {
  if (filePath.endsWith('.js')) {
    return 'application/javascript; charset=utf-8';
  }
  if (filePath.endsWith('.css')) {
    return 'text/css; charset=utf-8';
  }
  if (filePath.endsWith('.html')) {
    return 'text/html; charset=utf-8';
  }
  if (filePath.endsWith('.xhtml') || filePath.endsWith('.xml') || filePath.endsWith('.opf')) {
    return 'application/xhtml+xml; charset=utf-8';
  }
  if (filePath.endsWith('.ncx')) {
    return 'application/x-dtbncx+xml; charset=utf-8';
  }
  if (filePath.endsWith('.svg')) {
    return 'image/svg+xml';
  }
  if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (filePath.endsWith('.png')) {
    return 'image/png';
  }
  if (filePath.endsWith('.gif')) {
    return 'image/gif';
  }
  if (filePath.endsWith('.ttf')) {
    return 'font/ttf';
  }
  if (filePath.endsWith('.otf')) {
    return 'font/otf';
  }
  return 'application/octet-stream';
}

function buildHarnessHtml() {
  return `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Reader Render Diff Harness</title>
    <script src="/node_modules/epubjs/dist/epub.min.js"></script>
    <style>
      html, body {
        margin: 0;
        padding: 0;
        background: #ffffff;
        overflow: hidden;
      }

      #viewer {
        width: 100vw;
        height: 100vh;
      }
    </style>
  </head>
  <body>
    <div id="viewer"></div>
    <script>
      const BLOCK_SELECTOR = 'p,h1,h2,h3,h4,h5,h6,li,blockquote,pre,code,table,img,hr';

      function toHex(color) {
        if (!color || color === 'rgba(0, 0, 0, 0)' || color === 'transparent') {
          return null;
        }
        const canvas = document.createElement('canvas');
        canvas.width = 1;
        canvas.height = 1;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = color;
        const normalized = ctx.fillStyle;
        if (normalized.startsWith('#')) {
          const value = normalized.replace('#', '');
          if (value.length === 6) {
            return 'ff' + value.toLowerCase();
          }
          if (value.length === 8) {
            return value.toLowerCase();
          }
        }
        return null;
      }

      function parseLineCount(element, style, rect) {
        const raw = style.lineHeight;
        if (!raw || raw === 'normal') {
          return Math.max(1, Math.round(rect.height / ((parseFloat(style.fontSize) || 16) * 1.2)));
        }
        const lineHeight = parseFloat(raw);
        if (!lineHeight || Number.isNaN(lineHeight)) {
          return 1;
        }
        return Math.max(1, Math.round(rect.height / lineHeight));
      }

      function captureBlock(element) {
        const rect = element.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) {
          return null;
        }
        const viewportWidth = element.ownerDocument.defaultView.innerWidth;
        const viewportHeight = element.ownerDocument.defaultView.innerHeight;
        const intersectsViewport =
          rect.right > 0 &&
          rect.bottom > 0 &&
          rect.left < viewportWidth &&
          rect.top < viewportHeight;
        if (!intersectsViewport) {
          return null;
        }

        const style = getComputedStyle(element);
        const text = element.tagName.toLowerCase() === 'img'
          ? (element.alt || element.getAttribute('src') || '')
          : (element.innerText || element.textContent || '');

        return {
          nodeType: element.tagName,
          kind: element.tagName.toLowerCase() === 'img' ? 'image' : 'text',
          text,
          rect: {
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height
          },
          fontSize: parseFloat(style.fontSize || '0') || null,
          fontWeight: parseInt(style.fontWeight || '400', 10) || 400,
          italic: style.fontStyle === 'italic' || style.fontStyle === 'oblique',
          underline: (style.textDecorationLine || '').includes('underline'),
          strike: (style.textDecorationLine || '').includes('line-through'),
          colorHex: toHex(style.color),
          backgroundHex: toHex(style.backgroundColor),
          lineCount: parseLineCount(element, style, rect),
        };
      }

      window.renderHarness = {
        book: null,
        rendition: null,
        spineItems: [],

        async init({ epubUrl, width, height, preferences }) {
          this.book = ePub(epubUrl);
          await this.book.ready;
          this.spineItems = this.book.spine.spineItems;
          this.rendition = this.book.renderTo('viewer', {
            width,
            height,
            spread: 'none',
            flow: 'paginated',
            manager: 'default'
          });
          this.rendition.themes.default({
            body: {
              'font-size': preferences.baseFontSizePx + 'px',
              'line-height': String(preferences.lineHeightMultiplier),
              'padding-top': preferences.pageVerticalPaddingPx + 'px',
              'padding-bottom': preferences.pageVerticalPaddingPx + 'px',
              'padding-left': preferences.pageHorizontalPaddingPx + 'px',
              'padding-right': preferences.pageHorizontalPaddingPx + 'px',
              'margin': '0',
              'box-sizing': 'border-box',
              'font-family': preferences.fontFamily || 'Georgia, serif',
              'background': '#ffffff',
              'color': '#1a1a1a'
            }
          });
          await this.rendition.display();
          await this.waitForRender();
        },

        chapterCount() {
          return this.spineItems.length;
        },

        async displayChapter(chapterIndex) {
          const target = this.spineItems[chapterIndex];
          if (!target) {
            return null;
          }
          await this.rendition.display(target.href);
          await this.waitForRender();
          return this.capturePage();
        },

        async nextPage() {
          await this.rendition.next();
          await this.waitForRender();
          return this.capturePage();
        },

        async waitForRender() {
          await new Promise((resolve) => setTimeout(resolve, 80));
        },

        capturePage() {
          const location = this.rendition.currentLocation();
          if (!location || !location.start) {
            return null;
          }
          const iframe = document.querySelector('#viewer iframe');
          const doc = iframe?.contentDocument;
          if (!doc) {
            return null;
          }
          const blocks = Array.from(doc.querySelectorAll(BLOCK_SELECTOR))
            .map(captureBlock)
            .filter(Boolean);
          const pageIndex = Math.max(0, (location.start.displayed?.page || 1) - 1);
          return {
            chapterIndex: location.start.index,
            pageIndex,
            href: location.start.href,
            locationKey: location.start.cfi || location.start.href || String(pageIndex),
            blocks,
          };
        }
      };
    </script>
  </body>
</html>`;
}
