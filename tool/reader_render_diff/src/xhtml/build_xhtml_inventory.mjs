import fs from 'node:fs/promises';
import path from 'node:path';

import { parseXhtmlDom } from './parse_xhtml_dom.mjs';
import { normalizeText, stableHash, uniqueSorted } from '../shared/text_utils.mjs';

// ---------------------------------------------------------------------------
// Tag classification sets — must stay consistent with classify_browser_object.mjs
// ---------------------------------------------------------------------------

const BLOCK_TAG_MAP = {
  p: 'block.paragraph',
  h1: 'block.heading.h1',
  h2: 'block.heading.h2',
  h3: 'block.heading.h3',
  h4: 'block.heading.h4',
  h5: 'block.heading.h5',
  h6: 'block.heading.h6',
  table: 'block.table.basic',
  blockquote: 'block.blockquote',
  pre: 'block.code.pre',
  img: 'block.image',
  hr: 'block.horizontal_rule',
  dt: 'block.definition_list.dt',
  dd: 'block.definition_list.dd',
};

// ul/ol need special handling for nesting — see blockCaseForTag()
const LIST_TAGS = new Set(['ul', 'ol']);

const INLINE_TAG_MAP = {
  strong: 'inline.bold',
  b: 'inline.bold',
  em: 'inline.italic',
  i: 'inline.italic',
  cite: 'inline.italic',
  dfn: 'inline.italic',
  u: 'inline.underline',
  ins: 'inline.underline',
  del: 'inline.strikethrough',
  s: 'inline.strikethrough',
  a: 'inline.link',
  sup: 'inline.superscript',
  sub: 'inline.subscript',
  small: 'inline.small',
  mark: 'inline.mark',
  code: 'inline.inline_code',
  br: 'inline.line_break',
};

const FLATTENED_CONTAINER_TAGS = new Set([
  'div', 'span', 'section', 'article', 'body', 'html', 'main',
  'header', 'footer', 'nav', 'aside',
]);

const DISCARDED_TAGS = new Set([
  'script', 'style', 'link', 'meta', 'head', 'form', 'input',
  'iframe', 'noscript', 'audio', 'video', 'source', 'object', 'embed',
]);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Build XHTML inventory from an extracted EPUB directory.
 *
 * @param {object}   opts
 * @param {string}   opts.epubPath       — original EPUB path (stored in output for reference)
 * @param {string[]} opts.xhtmlPaths     — ordered list of chapter XHTML file paths (absolute)
 * @param {object}   opts.caseCatalog    — loaded case catalog ({ entries, byId })
 * @returns {object} xhtml inventory JSON structure
 */
export async function buildXhtmlInventory({ epubPath, xhtmlPaths, caseCatalog }) {
  const chapters = [];
  const globalCaseCounts = {};
  let totalElements = 0;

  for (let chapterIndex = 0; chapterIndex < xhtmlPaths.length; chapterIndex++) {
    const xhtmlPath = xhtmlPaths[chapterIndex];
    const xhtmlContent = await fs.readFile(xhtmlPath, 'utf8');
    const chapter = buildChapterInventory({
      chapterIndex,
      xhtmlPath: path.basename(xhtmlPath),
      xhtmlContent,
      caseCatalog,
    });
    chapters.push(chapter);
    totalElements += chapter.elements.length;

    // Accumulate case counts
    for (const element of chapter.elements) {
      increment(globalCaseCounts, element.blockCaseId);
      for (const caseId of element.featureCaseIds) {
        increment(globalCaseCounts, caseId);
      }
      for (const caseId of element.layoutCaseIds) {
        increment(globalCaseCounts, caseId);
      }
    }
    for (const [caseId, count] of Object.entries(chapter.specialCaseCounts)) {
      globalCaseCounts[caseId] = (globalCaseCounts[caseId] ?? 0) + count;
    }
  }

  return {
    epubPath,
    chapters,
    summary: {
      totalElements,
      byCaseId: globalCaseCounts,
    },
  };
}

/**
 * Build inventory for a single chapter from its XHTML content string.
 * Exported for direct use in tests without file I/O.
 */
export function buildChapterInventory({ chapterIndex, xhtmlPath, xhtmlContent, caseCatalog }) {
  const document = parseXhtmlDom(xhtmlContent);
  const body = document.body ?? document.querySelector('body') ?? document.documentElement;

  const elements = [];
  const specialCaseCounts = {};
  let domOrderIndex = 0;

  walkDom(body, {
    chapterIndex,
    elements,
    specialCaseCounts,
    caseCatalog,
    getDomOrderIndex: () => domOrderIndex++,
    insidePre: false,
    ancestorListDepth: 0,
  });

  return {
    chapterIndex,
    xhtmlPath,
    elements,
    specialCaseCounts,
  };
}

// ---------------------------------------------------------------------------
// DOM walker
// ---------------------------------------------------------------------------

function walkDom(node, ctx) {
  if (node.nodeType !== 1 /* ELEMENT_NODE */) {
    return;
  }

  const tagName = (node.tagName ?? '').toLowerCase();

  // Special: discarded non-reading content — count and skip entirely
  if (DISCARDED_TAGS.has(tagName)) {
    increment(ctx.specialCaseCounts, 'special.discarded_nonreading_content');
    return;
  }

  // Special: check inline style for display:none or position:absolute/fixed
  const inlineStyle = parseInlineStyle(node.getAttribute('style') ?? '');
  if (inlineStyle.display === 'none') {
    increment(ctx.specialCaseCounts, 'special.display_none');
    return;
  }
  const position = inlineStyle.position ?? '';
  if (position === 'absolute' || position === 'fixed') {
    increment(ctx.specialCaseCounts, 'special.out_of_flow_absolute_fixed');
    return;
  }

  // Flattened container — count, then recurse into children
  if (FLATTENED_CONTAINER_TAGS.has(tagName)) {
    increment(ctx.specialCaseCounts, 'special.flattened_container');
    walkChildren(node, ctx);
    return;
  }

  // List tags — handled as block elements, then recurse into li children
  // to discover nested lists
  if (LIST_TAGS.has(tagName)) {
    const isNested = ctx.ancestorListDepth > 0;
    const blockCaseId = isNested
      ? 'block.list.nested'
      : tagName === 'ul'
        ? 'block.list.ul'
        : 'block.list.ol';

    emitBlockElement(node, tagName, blockCaseId, inlineStyle, ctx);
    // Walk children so nested lists inside <li> are discovered.
    // Don't increment depth here — <li> handler does that.
    walkChildren(node, ctx);
    return;
  }

  // Known block tags
  const blockCaseId = BLOCK_TAG_MAP[tagName];
  if (blockCaseId != null) {
    emitBlockElement(node, tagName, blockCaseId, inlineStyle, ctx);
    return;
  }

  // li — not a block element itself, but a container for content inside lists.
  // Recurse into children, increasing list depth so nested lists are detected.
  if (tagName === 'li') {
    walkChildren(node, { ...ctx, ancestorListDepth: ctx.ancestorListDepth + 1 });
    return;
  }

  // dl — definition list container, recurse for dt/dd children
  if (tagName === 'dl') {
    walkChildren(node, ctx);
    return;
  }

  // figure/figcaption — recurse for inner block content
  if (tagName === 'figure' || tagName === 'figcaption') {
    walkChildren(node, ctx);
    return;
  }

  // Unknown elements — try recursing into children in case they contain blocks
  walkChildren(node, ctx);
}

function walkChildren(parent, ctx) {
  for (const child of parent.childNodes) {
    walkDom(child, ctx);
  }
}

// ---------------------------------------------------------------------------
// Block element emission
// ---------------------------------------------------------------------------

function emitBlockElement(node, tagName, blockCaseId, inlineStyle, ctx) {
  const index = ctx.getDomOrderIndex();
  const insidePre = tagName === 'pre' || ctx.insidePre;
  const textContent = normalizeText(node.textContent ?? '');
  const contentHash = stableHash(textContent).slice(0, 6);
  const elementId = `ch${ctx.chapterIndex}_${tagName}_${index}_${contentHash}`;
  const domPath = buildDomPath(node);

  const featureCaseIds = uniqueSorted(detectInlineFeatures(node, insidePre));
  const layoutCaseIds = uniqueSorted(detectLayoutFeatures(inlineStyle, tagName, node));
  const status = ctx.caseCatalog.byId[blockCaseId]?.status ?? 'unsupported';

  ctx.elements.push({
    elementId,
    domPath,
    tagName,
    blockCaseId,
    featureCaseIds,
    layoutCaseIds,
    normalizedText: textContent,
    status,
  });
}

// ---------------------------------------------------------------------------
// Inline feature detection — recursive walk of children
// ---------------------------------------------------------------------------

function detectInlineFeatures(node, insidePre) {
  const features = [];
  walkInlineChildren(node, features, insidePre);
  return features;
}

function walkInlineChildren(node, features, insidePre) {
  for (const child of node.childNodes) {
    if (child.nodeType !== 1) {
      continue;
    }
    const tag = (child.tagName ?? '').toLowerCase();

    // code inside pre is part of the code block, not inline code
    if (tag === 'code' && insidePre) {
      walkInlineChildren(child, features, insidePre);
      continue;
    }

    // img inside a block → inline image
    if (tag === 'img') {
      features.push('inline.inline_image_alt_fallback');
      continue;
    }

    const inlineCaseId = INLINE_TAG_MAP[tag];
    if (inlineCaseId != null) {
      features.push(inlineCaseId);
    }

    // Recurse to find nested inline features (e.g. <strong><em>text</em></strong>)
    walkInlineChildren(child, features, insidePre);
  }
}

// ---------------------------------------------------------------------------
// Layout feature detection from inline styles + element defaults
// ---------------------------------------------------------------------------

function detectLayoutFeatures(inlineStyle, tagName, node) {
  const features = [];

  // Text alignment — from inline style or element-level defaults
  const textAlign = inlineStyle['text-align'] ?? elementDefaultAlign(tagName);
  if (textAlign === 'center') {
    features.push('layout.align.center');
  } else if (textAlign === 'right' || textAlign === 'end') {
    features.push('layout.align.right');
  } else if (textAlign === 'justify') {
    features.push('layout.align.justify');
  } else if (textAlign === 'left' || textAlign === 'start') {
    features.push('layout.align.left');
  }

  // Margin — from inline style or element-level defaults
  if (
    hasPositiveLength(inlineStyle['margin']) ||
    hasPositiveLength(inlineStyle['margin-top']) ||
    hasPositiveLength(inlineStyle['margin-bottom']) ||
    hasPositiveLength(inlineStyle['margin-left']) ||
    hasPositiveLength(inlineStyle['margin-right']) ||
    elementDefaultMargin(tagName)
  ) {
    features.push('layout.margin');
  }

  // Padding
  if (
    hasPositiveLength(inlineStyle['padding']) ||
    hasPositiveLength(inlineStyle['padding-top']) ||
    hasPositiveLength(inlineStyle['padding-bottom']) ||
    hasPositiveLength(inlineStyle['padding-left']) ||
    hasPositiveLength(inlineStyle['padding-right'])
  ) {
    features.push('layout.padding');
  }

  // Text indent
  if (hasPositiveLength(inlineStyle['text-indent'])) {
    features.push('layout.text_indent');
  }

  // Line height
  if (hasPositiveLength(inlineStyle['line-height'])) {
    features.push('layout.line_height');
  }

  // Text color
  if (inlineStyle['color'] != null) {
    features.push('layout.text_color');
  }

  // Background color
  if (inlineStyle['background-color'] != null || inlineStyle['background'] != null) {
    features.push('layout.background_color');
  }

  // List style type
  if (tagName === 'ul' || tagName === 'ol') {
    const listStyle = inlineStyle['list-style-type'];
    if (listStyle != null) {
      const listCaseId = LIST_STYLE_TO_LAYOUT_CASE[listStyle];
      if (listCaseId != null) {
        features.push(listCaseId);
      }
    }
  }

  // Table sub-cases
  if (tagName === 'table') {
    features.push(...detectTableSubCases(node));
  }

  // Image width hint
  if (tagName === 'img') {
    if (
      inlineStyle['width'] != null ||
      node.getAttribute('width') != null
    ) {
      features.push('layout.image.width_hint');
    }
  }

  return features;
}

const LIST_STYLE_TO_LAYOUT_CASE = {
  disc: 'layout.list_style.disc',
  circle: 'layout.list_style.circle',
  square: 'layout.list_style.square',
  decimal: 'layout.list_style.decimal',
  'lower-alpha': 'layout.list_style.lower_alpha',
  'upper-alpha': 'layout.list_style.upper_alpha',
  'lower-roman': 'layout.list_style.lower_roman',
  'upper-roman': 'layout.list_style.upper_roman',
};

function detectTableSubCases(tableNode) {
  const cases = [];
  if (tableNode.querySelector('caption')) {
    cases.push('block.table.caption');
  }
  if (tableNode.querySelector('th')) {
    cases.push('block.table.header_row');
  }
  const cellsWithColspan = tableNode.querySelectorAll('[colspan]');
  for (const cell of cellsWithColspan) {
    const val = Number.parseInt(cell.getAttribute('colspan'), 10);
    if (val > 1) {
      cases.push('block.table.colspan');
      break;
    }
  }
  const cellsWithRowspan = tableNode.querySelectorAll('[rowspan]');
  for (const cell of cellsWithRowspan) {
    const val = Number.parseInt(cell.getAttribute('rowspan'), 10);
    if (val > 1) {
      cases.push('block.table.rowspan');
      break;
    }
  }
  return cases;
}

/**
 * Element-level default text-align for tags with intrinsic alignment.
 */
function elementDefaultAlign(tagName) {
  if (tagName === 'center') {
    return 'center';
  }
  return null;
}

/**
 * Whether a tag has intrinsic margin (element-level default).
 */
function elementDefaultMargin(tagName) {
  return tagName === 'blockquote';
}

// ---------------------------------------------------------------------------
// DOM path builder
// ---------------------------------------------------------------------------

function buildDomPath(node) {
  const segments = [];
  let current = node;
  while (current && current.nodeType === 1) {
    const tag = (current.tagName ?? '').toLowerCase();
    if (tag === 'body' || tag === 'html') {
      segments.unshift(tag);
      break;
    }
    const parent = current.parentNode;
    if (parent) {
      const siblings = [...parent.childNodes].filter(
        (sibling) => sibling.nodeType === 1 && (sibling.tagName ?? '').toLowerCase() === tag,
      );
      if (siblings.length > 1) {
        const childIndex = siblings.indexOf(current) + 1;
        segments.unshift(`${tag}:nth-child(${childIndex})`);
      } else {
        segments.unshift(tag);
      }
    } else {
      segments.unshift(tag);
    }
    current = parent;
  }
  return segments.join(' > ');
}

// ---------------------------------------------------------------------------
// Inline style parser (v1 — simple property extraction)
// ---------------------------------------------------------------------------

function parseInlineStyle(styleString) {
  if (!styleString) {
    return {};
  }
  const result = {};
  for (const declaration of styleString.split(';')) {
    const colonIndex = declaration.indexOf(':');
    if (colonIndex < 0) {
      continue;
    }
    const prop = declaration.slice(0, colonIndex).trim().toLowerCase();
    const value = declaration.slice(colonIndex + 1).trim().toLowerCase();
    if (prop && value) {
      result[prop] = value;
    }
  }
  return result;
}

/**
 * Whether a CSS value string represents a positive length (e.g. "10px", "1em", "2rem").
 */
function hasPositiveLength(value) {
  if (value == null) {
    return false;
  }
  const num = Number.parseFloat(value);
  return Number.isFinite(num) && num > 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function increment(counts, key) {
  counts[key] = (counts[key] ?? 0) + 1;
}
