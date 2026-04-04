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
    const chapterSpecialCases = [];

    for (const chapterIndex of chapterIndices) {
      let current = await page.evaluate(
        async (index) => window.renderHarness.displayChapter(index),
        chapterIndex,
      );
      if (current == null) {
        chapterPageCounts[String(chapterIndex)] = 0;
        continue;
      }

      const chapterAudit = await page.evaluate(() => window.renderHarness.scanChapterSpecialCases());
      chapterSpecialCases.push({
        chapterIndex,
        cases: chapterAudit?.cases ?? [],
      });

      let capturedPages = 0;
      chapterPageCounts[String(chapterIndex)] = 0;

      while (
        current != null &&
        current.chapterIndex === chapterIndex &&
        current.actualHref === current.spineHref &&
        (config.maxPagesPerChapter == null ||
          capturedPages < config.maxPagesPerChapter)
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
          next.actualHref !== next.spineHref ||
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
      chapterSpecialCases,
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
  const length =
    config.maxChapters == null ? totalCount : Math.min(totalCount, config.maxChapters);
  return Array.from({ length }, (_, index) => index);
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
      const bytes = await fs.readFile(filePath).catch(() => null);
      if (bytes == null) {
        response.writeHead(404);
        response.end('Not found');
        return;
      }
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
      const BLOCK_SELECTOR = 'p,h1,h2,h3,h4,h5,h6,ol,ul,table,blockquote,pre,img,hr,dt,dd';
      const SPECIAL_FLATTEN_SELECTOR = 'div,span,section,article,body,html,main,header,footer,nav,aside';
      const SPECIAL_DISCARDED_SELECTOR = 'script,style,link,meta,head,form,input,iframe,noscript,audio,video,source,object,embed';

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
        const rgba = normalized.match(/rgba?\\(([^)]+)\\)/i);
        if (!rgba) {
          return null;
        }
        const parts = rgba[1].split(',').map((part) => Number.parseFloat(part.trim()));
        const alpha = Math.round((parts[3] == null ? 1 : parts[3]) * 255);
        return [alpha, parts[0], parts[1], parts[2]]
          .map((part) => Math.max(0, Math.min(255, Math.round(part))).toString(16).padStart(2, '0'))
          .join('');
      }

      function parseNumeric(value) {
        const parsed = Number.parseFloat(value);
        return Number.isFinite(parsed) ? parsed : null;
      }

      function parseLineCount(style, rect) {
        const lineHeight = parseNumeric(style.lineHeight);
        if (lineHeight == null || lineHeight <= 0) {
          const fontSize = parseNumeric(style.fontSize) ?? 16;
          return Math.max(1, Math.round(rect.height / (fontSize * 1.2)));
        }
        return Math.max(1, Math.round(rect.height / lineHeight));
      }

      function rectIntersectsViewport(rect, viewportWidth, viewportHeight) {
        return (
          rect.right > 0 &&
          rect.bottom > 0 &&
          rect.left < viewportWidth &&
          rect.top < viewportHeight
        );
      }

      function visibleFragmentRect(element, viewportWidth, viewportHeight) {
        const rects = Array.from(element.getClientRects()).filter((rect) =>
          rect.width > 0 &&
          rect.height > 0 &&
          rectIntersectsViewport(rect, viewportWidth, viewportHeight)
        );
        if (rects.length === 0) {
          return null;
        }

        const left = Math.max(0, Math.min(...rects.map((rect) => rect.left)));
        const top = Math.max(0, Math.min(...rects.map((rect) => rect.top)));
        const right = Math.min(viewportWidth, Math.max(...rects.map((rect) => rect.right)));
        const bottom = Math.min(viewportHeight, Math.max(...rects.map((rect) => rect.bottom)));
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

      function extractVisibleText(element, viewportWidth, viewportHeight) {
        const ownerDocument = element.ownerDocument;
        const walker = ownerDocument.createTreeWalker(
          element,
          NodeFilter.SHOW_TEXT,
          {
            acceptNode(node) {
              return (node.textContent || '').trim()
                ? NodeFilter.FILTER_ACCEPT
                : NodeFilter.FILTER_REJECT;
            }
          }
        );

        const words = [];
        while (walker.nextNode()) {
          const node = walker.currentNode;
          const text = node.textContent || '';
          const matches = text.matchAll(/\\S+/g);
          for (const match of matches) {
            if (match.index == null) {
              continue;
            }
            const range = ownerDocument.createRange();
            range.setStart(node, match.index);
            range.setEnd(node, match.index + match[0].length);
            const rects = Array.from(range.getClientRects());
            const visible = rects.some((rect) =>
              rect.width > 0 &&
              rect.height > 0 &&
              rectIntersectsViewport(rect, viewportWidth, viewportHeight)
            );
            range.detach?.();
            if (visible) {
              words.push(match[0]);
            }
          }
        }
        return words.join(' ').trim();
      }

      function buildDomPath(element) {
        const segments = [];
        let current = element;
        while (current && current.nodeType === Node.ELEMENT_NODE && current.tagName.toLowerCase() !== 'html') {
          const tag = current.tagName.toLowerCase();
          let index = 1;
          let sibling = current.previousElementSibling;
          while (sibling) {
            if (sibling.tagName.toLowerCase() === tag) {
              index += 1;
            }
            sibling = sibling.previousElementSibling;
          }
          segments.push(tag + ':nth-of-type(' + index + ')');
          current = current.parentElement;
        }
        segments.push('html');
        return segments.reverse().join('>');
      }

      function hasStyledDescendant(root, predicate) {
        if (predicate(root)) {
          return true;
        }
        const descendants = root.querySelectorAll('*');
        for (const node of descendants) {
          if (predicate(node)) {
            return true;
          }
        }
        return false;
      }

      function summarizeStyle(element, rect) {
        const style = getComputedStyle(element);
        return {
          fontSizePx: parseNumeric(style.fontSize),
          fontWeight: Number.parseInt(style.fontWeight || '400', 10) || 400,
          fontStyle: style.fontStyle || 'normal',
          textAlign: style.textAlign || 'left',
          colorHex: toHex(style.color),
          backgroundHex: toHex(style.backgroundColor),
          lineHeightPx: parseNumeric(style.lineHeight),
          marginTopPx: parseNumeric(style.marginTop),
          marginBottomPx: parseNumeric(style.marginBottom),
          marginLeftPx: parseNumeric(style.marginLeft),
          marginRightPx: parseNumeric(style.marginRight),
          paddingTopPx: parseNumeric(style.paddingTop),
          paddingBottomPx: parseNumeric(style.paddingBottom),
          paddingLeftPx: parseNumeric(style.paddingLeft),
          paddingRightPx: parseNumeric(style.paddingRight),
          textIndentPx: parseNumeric(style.textIndent),
          listStyleType: style.listStyleType || null,
          verticalAlign: style.verticalAlign || null,
          position: style.position || null,
          display: style.display || null,
          renderedWidthPx: rect.width,
          renderedHeightPx: rect.height,
        };
      }

      function extractFeatureFlags(element) {
        return {
          bold: hasStyledDescendant(
            element,
            (node) =>
              ['b', 'strong'].includes(node.tagName.toLowerCase()) ||
              (Number.parseInt(getComputedStyle(node).fontWeight || '400', 10) || 400) >= 600,
          ),
          italic: hasStyledDescendant(
            element,
            (node) =>
              ['i', 'em', 'cite', 'dfn'].includes(node.tagName.toLowerCase()) ||
              ['italic', 'oblique'].includes(getComputedStyle(node).fontStyle),
          ),
          underline: hasStyledDescendant(
            element,
            (node) =>
              ['u', 'a'].includes(node.tagName.toLowerCase()) ||
              (getComputedStyle(node).textDecorationLine || '').includes('underline'),
          ),
          strikethrough: hasStyledDescendant(
            element,
            (node) =>
              ['s', 'strike', 'del'].includes(node.tagName.toLowerCase()) ||
              (getComputedStyle(node).textDecorationLine || '').includes('line-through'),
          ),
          link: element.matches('a[href]') || element.querySelector('a[href]') != null,
          superscript: hasStyledDescendant(
            element,
            (node) =>
              node.tagName.toLowerCase() === 'sup' ||
              getComputedStyle(node).verticalAlign === 'super',
          ),
          subscript: hasStyledDescendant(
            element,
            (node) =>
              node.tagName.toLowerCase() === 'sub' ||
              getComputedStyle(node).verticalAlign === 'sub',
          ),
          small: hasStyledDescendant(
            element,
            (node) => node.tagName.toLowerCase() === 'small',
          ),
          mark: hasStyledDescendant(
            element,
            (node) => node.tagName.toLowerCase() === 'mark',
          ),
          inlineCode: hasStyledDescendant(
            element,
            (node) => ['code', 'kbd', 'samp', 'tt'].includes(node.tagName.toLowerCase()),
          ),
          lineBreak: element.querySelector('br') != null,
          inlineImage: element.tagName.toLowerCase() !== 'img' && element.querySelector('img') != null,
        };
      }

      function extractListInfo(element) {
        const tag = element.tagName.toLowerCase();
        if (tag !== 'ul' && tag !== 'ol') {
          return null;
        }
        const style = getComputedStyle(element);
        const ancestorLists = [];
        let current = element.parentElement;
        while (current) {
          const currentTag = current.tagName.toLowerCase();
          if (currentTag === 'ul' || currentTag === 'ol') {
            ancestorLists.push(current);
          }
          current = current.parentElement;
        }
        return {
          ordered: tag === 'ol',
          listStyleType: style.listStyleType || null,
          nestingDepth: ancestorLists.length,
          itemCount: element.querySelectorAll(':scope > li').length,
        };
      }

      function hasBorder(element) {
        const style = getComputedStyle(element);
        const widths = [
          parseNumeric(style.borderTopWidth),
          parseNumeric(style.borderRightWidth),
          parseNumeric(style.borderBottomWidth),
          parseNumeric(style.borderLeftWidth),
        ];
        return widths.some((value) => value != null && value > 0);
      }

      function extractTableInfo(element) {
        if (element.tagName.toLowerCase() !== 'table') {
          return null;
        }
        const cells = Array.from(element.querySelectorAll('th,td'));
        return {
          rowCount: element.querySelectorAll('tr').length,
          cellCount: cells.length,
          hasCaption: element.querySelector('caption') != null,
          hasHeaderRow: element.querySelector('th') != null,
          hasColspan: cells.some((cell) => Number(cell.getAttribute('colspan') || '1') > 1),
          hasRowspan: cells.some((cell) => Number(cell.getAttribute('rowspan') || '1') > 1),
          hasBorders: hasBorder(element) || cells.some((cell) => hasBorder(cell)),
          hasCellBackground: cells.some((cell) => {
            const bg = getComputedStyle(cell).backgroundColor;
            return bg && bg !== 'transparent' && bg !== 'rgba(0, 0, 0, 0)';
          }),
          hasVerticalAlign: cells.some((cell) => {
            const value = getComputedStyle(cell).verticalAlign;
            return value && value !== 'middle' && value !== 'baseline';
          }),
        };
      }

      function basename(src) {
        if (!src) {
          return null;
        }
        try {
          const url = new URL(src, document.baseURI);
          return url.pathname.split('/').filter(Boolean).pop() || null;
        } catch {
          return src.split('/').filter(Boolean).pop() || null;
        }
      }

      function extractImageInfo(element, rect) {
        if (element.tagName.toLowerCase() !== 'img') {
          return null;
        }
        const style = getComputedStyle(element);
        return {
          alt: element.getAttribute('alt') || null,
          srcBasename: basename(element.currentSrc || element.getAttribute('src') || ''),
          naturalWidth: element.naturalWidth || null,
          naturalHeight: element.naturalHeight || null,
          renderedWidth: rect.width,
          renderedHeight: rect.height,
          widthHint:
            style.width && style.width !== 'auto'
              ? style.width
              : null,
        };
      }

      function shouldCaptureBlock(element) {
        const tag = element.tagName.toLowerCase();
        const parent = element.parentElement;
        if (!parent) {
          return true;
        }

        if (tag === 'img') {
          return parent.closest('p,h1,h2,h3,h4,h5,h6,blockquote,pre,table,dt,dd,li') == null;
        }

        if (tag === 'hr') {
          return parent.closest('table') == null;
        }

        if (tag === 'ul' || tag === 'ol') {
          return parent.closest('table') == null;
        }

        if (/^h[1-6]$/.test(tag) || tag === 'p' || tag === 'dt' || tag === 'dd') {
          return parent.closest('blockquote,pre,table,dt,dd,li') == null;
        }

        if (tag === 'blockquote' || tag === 'pre') {
          return parent.closest('table,li') == null;
        }

        if (tag === 'table') {
          return true;
        }

        return true;
      }

      function captureBlock(element) {
        if (!shouldCaptureBlock(element)) {
          return null;
        }

        const viewportWidth = window.renderHarness.pageWidth;
        const viewportHeight = window.renderHarness.pageHeight;
        const rect = element.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) {
          return null;
        }

        const visibleRect = visibleFragmentRect(element, viewportWidth, viewportHeight);
        if (visibleRect == null) {
          return null;
        }

        const tagName = element.tagName.toLowerCase();
        const fullText = tagName === 'img'
          ? (element.getAttribute('alt') || element.getAttribute('src') || '')
          : (element.innerText || element.textContent || '').trim();
        const visibleText = tagName === 'img'
          ? fullText
          : (extractVisibleText(element, viewportWidth, viewportHeight) || fullText);
        if (tagName !== 'img' && tagName !== 'hr' && !fullText) {
          return null;
        }

        const styleSummary = summarizeStyle(element, visibleRect);
        return {
          tagName,
          nodeType: element.tagName,
          kind: tagName === 'img' ? 'image' : tagName === 'hr' ? 'rule' : 'text',
          domPath: buildDomPath(element),
          fullText,
          visibleText,
          rect: {
            left: visibleRect.left,
            top: visibleRect.top,
            width: visibleRect.width,
            height: visibleRect.height,
          },
          computedStyleSummary: styleSummary,
          featureFlags: extractFeatureFlags(element),
          listInfo: extractListInfo(element),
          tableInfo: extractTableInfo(element),
          imageInfo: extractImageInfo(element, visibleRect),
          lineCount: tagName === 'img' || tagName === 'hr'
            ? 0
            : parseLineCount(getComputedStyle(element), visibleRect),
        };
      }

      function scanChapterSpecialCases() {
        const iframe = document.querySelector('#viewer iframe');
        const doc = iframe?.contentDocument;
        if (!doc) {
          return { cases: [] };
        }

        const counts = new Map();
        const examples = new Map();

        function record(caseId, element) {
          counts.set(caseId, (counts.get(caseId) || 0) + 1);
          const current = examples.get(caseId) || [];
          if (current.length < 3) {
            current.push({
              tagName: element.tagName.toLowerCase(),
              domPath: buildDomPath(element),
            });
            examples.set(caseId, current);
          }
        }

        for (const element of doc.querySelectorAll(SPECIAL_FLATTEN_SELECTOR)) {
          const content = (element.textContent || '').trim();
          if (content !== '' || element.childElementCount > 0) {
            record('special.flattened_container', element);
          }
        }

        for (const element of doc.querySelectorAll(SPECIAL_DISCARDED_SELECTOR)) {
          record('special.discarded_nonreading_content', element);
        }

        for (const element of doc.querySelectorAll('*')) {
          const style = getComputedStyle(element);
          if (style.display === 'none') {
            record('special.display_none', element);
          }
          if (style.position === 'absolute' || style.position === 'fixed') {
            record('special.out_of_flow_absolute_fixed', element);
          }
        }

        return {
          cases: [...counts.entries()]
            .sort((a, b) => a[0].localeCompare(b[0]))
            .map(([caseId, count]) => ({
              caseId,
              count,
              examples: examples.get(caseId) || [],
            })),
        };
      }

      window.renderHarness = {
        book: null,
        rendition: null,
        spineItems: [],
        activeChapterIndex: 0,
        activeSpineHref: '',
        pageWidth: 0,
        pageHeight: 0,

        async init({ epubUrl, width, height, preferences }) {
          this.pageWidth = width;
          this.pageHeight = height;
          this.book = ePub(epubUrl);
          await this.book.ready;
          this.spineItems = this.book.spine.spineItems;
          this.rendition = this.book.renderTo('viewer', {
            width,
            height,
            spread: 'none',
            flow: 'paginated',
            manager: 'default',
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
              'color': '#1a1a1a',
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
          this.activeChapterIndex = chapterIndex;
          this.activeSpineHref = target.href;
          await this.rendition.display(target.href);
          await this.waitForRender();
          return this.capturePage();
        },

        async nextPage() {
          await this.rendition.next();
          await this.waitForRender();
          return this.capturePage();
        },

        scanChapterSpecialCases,

        async waitForRender() {
          await new Promise((resolve) => setTimeout(resolve, 120));
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
            .filter(Boolean)
            .sort((a, b) => a.rect.top - b.rect.top || a.rect.left - b.rect.left);
          const pageIndex = Math.max(0, (location.start.displayed?.page || 1) - 1);
          return {
            chapterIndex: this.activeChapterIndex,
            pageIndex,
            href: location.start.href,
            actualHref: location.start.href,
            spineHref: this.activeSpineHref,
            locationKey: location.start.cfi || location.start.href || String(pageIndex),
            blocks,
          };
        }
      };
    </script>
  </body>
</html>`;
}
