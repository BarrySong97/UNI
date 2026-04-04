import { canonicalizeText, normalizeText, excerptText } from '../shared/text_utils.mjs';

// ---------------------------------------------------------------------------
// RenderNode type → block case mapping (mirrors classify_canvas_object.mjs)
// ---------------------------------------------------------------------------

const RENDER_NODE_TYPE_TO_CASE = {
  Paragraph: 'block.paragraph',
  Heading: 'block.heading',    // needs level suffix
  List: 'block.list',          // needs ordered check
  Table: 'block.table.basic',
  BlockQuote: 'block.blockquote',
  CodeBlock: 'block.code.pre',
  Image: 'block.image',
  HorizontalRule: 'block.horizontal_rule',
};

// Block cases that map to ParagraphNode in the parser (compatible mappings)
const COMPATIBLE_RENDER_NODE_TYPES = {
  'block.definition_list.dt': ['Paragraph'],
  'block.definition_list.dd': ['Paragraph'],
};

// Inline feature → RenderNode Text property mapping
const INLINE_FEATURE_CHECKS = {
  'inline.bold': { property: 'bold', value: true },
  'inline.italic': { property: 'italic', value: true },
  'inline.underline': { property: 'underline', value: true },
  'inline.strikethrough': { property: 'line_through', value: true },
  'inline.superscript': { property: 'superscript', value: true },
  'inline.subscript': { property: 'subscript', value: true },
};

// Layout align feature → expected RenderNode align value
const LAYOUT_ALIGN_CHECKS = {
  'layout.align.center': 'Center',
  'layout.align.right': 'Right',
  'layout.align.left': 'Left',
  'layout.align.justify': 'Justify',
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Compare XHTML inventory against Rust parser chapter JSON output to find
 * structural gaps — elements present in source XHTML but missing or
 * incomplete in the parser output.
 *
 * @param {object} opts
 * @param {object} opts.xhtmlInventory — output from buildXhtmlInventory
 * @param {object[]} opts.chapterJsons — array of parsed chapter JSON objects
 * @param {object} opts.caseCatalog — loaded case catalog ({ entries, byId })
 * @returns {object} structural gaps report
 */
export function findStructuralGaps({ xhtmlInventory, chapterJsons, caseCatalog }) {
  const allGaps = [];
  let totalXhtmlElements = 0;
  let matchedElements = 0;
  let missingElements = 0;
  let featureGapCount = 0;
  let overConvertedNodes = 0;

  for (const chapter of xhtmlInventory.chapters) {
    const chapterIndex = chapter.chapterIndex;
    const chapterJson = chapterJsons[chapterIndex];

    // Build canvas-side inventory from parser output
    const parserNodes = chapterJson
      ? buildParserInventory(chapterJson)
      : [];

    // Track which parser nodes got matched
    const matchedParserNodeIndices = new Set();

    totalXhtmlElements += chapter.elements.length;

    // --- Element-level matching ---
    for (const element of chapter.elements) {
      // Skip special.* cases — they are expected to have no RenderNode
      if (element.blockCaseId.startsWith('special.')) {
        continue;
      }

      // Skip whitespace-only text-bearing elements WITH no inline features —
      // parser intentionally strips truly empty paragraphs/headings.
      // Elements with inline features (e.g. <p><img></p> which has
      // inline.inline_image_alt_fallback) are kept even if text is empty.
      if (!isNonTextElement(element) &&
          isWhitespaceOnly(element.normalizedText) &&
          (element.featureCaseIds ?? []).length === 0) {
        continue;
      }

      const match = findBestMatch(element, parserNodes, matchedParserNodeIndices);

      if (match != null) {
        matchedParserNodeIndices.add(match.index);
        matchedElements += 1;

        // --- Feature gap detection on matched elements ---
        const elementFeatureGaps = detectFeatureGaps(
          element, match.node, chapterIndex, caseCatalog,
        );
        for (const gap of elementFeatureGaps) {
          allGaps.push(gap);
          featureGapCount += 1;
        }
      } else {
        // Check if this element's case is supported/partial — only then it's a gap
        const status = element.status;
        if (status === 'supported' || status === 'partial') {
          missingElements += 1;
          allGaps.push({
            type: 'missing_element',
            chapterIndex,
            elementId: element.elementId,
            domPath: element.domPath,
            blockCaseId: element.blockCaseId,
            normalizedText: excerptText(element.normalizedText),
            status,
            hint: buildMissingElementHint(element),
          });
        }
      }
    }

    // --- Over-conversion detection ---
    for (let i = 0; i < parserNodes.length; i++) {
      if (matchedParserNodeIndices.has(i)) {
        continue;
      }
      const node = parserNodes[i];
      overConvertedNodes += 1;
      allGaps.push({
        type: 'over_converted',
        chapterIndex,
        renderNodeKind: node.renderNodeType,
        normalizedText: excerptText(node.normalizedText),
        hint: buildOverConvertedHint(node),
      });
    }
  }

  const gapScore = missingElements * 3 + featureGapCount * 1 + overConvertedNodes * 2;

  return {
    summary: {
      totalXhtmlElements,
      matchedElements,
      missingElements,
      featureGaps: featureGapCount,
      overConvertedNodes,
      gapScore,
    },
    gaps: allGaps,
  };
}

// ---------------------------------------------------------------------------
// Parser inventory builder — walks RenderNode JSON to build flat list
// ---------------------------------------------------------------------------

/**
 * Build a flat list of parser node descriptors from chapter JSON.
 */
export function buildParserInventory(chapterJson) {
  const nodes = [];
  for (const renderNode of chapterJson.nodes ?? []) {
    walkRenderNode(renderNode, nodes);
  }
  return nodes;
}

function walkRenderNode(node, output) {
  const type = node.type;
  if (type == null) {
    return;
  }

  // Skip standalone Text and LineBreak nodes — these are inline fragments
  // that should be children of a block node, not top-level entries.
  // The Rust parser sometimes emits them alongside HorizontalRule or as
  // bare content. They are not block-level elements and should not participate
  // in structural matching.
  if (type === 'Text' || type === 'LineBreak') {
    return;
  }

  const descriptor = {
    renderNodeType: type,
    blockCaseId: resolveBlockCaseId(node),
    normalizedText: extractNodeText(node),
    canonicalText: canonicalizeText(extractNodeText(node)),
    align: node.align ?? null,
    textChildren: extractTextChildren(node),
    raw: node,
  };

  output.push(descriptor);

  // For container nodes like BlockQuote that contain child nodes,
  // we do NOT recurse — the BlockQuote itself IS the element to match.
  // The Rust parser flattens children into the parent node's children array.
}

/**
 * Resolve the block case ID for a RenderNode.
 */
export function resolveBlockCaseId(node) {
  const type = node.type;

  if (type === 'Heading') {
    const level = node.level ?? 1;
    return `block.heading.h${level}`;
  }

  if (type === 'List') {
    return node.ordered ? 'block.list.ol' : 'block.list.ul';
  }

  return RENDER_NODE_TYPE_TO_CASE[type] ?? null;
}

/**
 * Extract all text content from a RenderNode, recursively collecting from
 * children, items, rows, etc.
 */
export function extractNodeText(node) {
  const parts = [];
  collectText(node, parts);
  return normalizeText(parts.join(' '));
}

function collectText(node, parts) {
  // Direct text content (CodeBlock)
  if (node.text != null) {
    parts.push(node.text);
  }

  // Direct content (Text child)
  if (node.content != null) {
    parts.push(node.content);
  }

  // Alt text for images
  if (node.type === 'Image' && node.alt != null) {
    parts.push(node.alt);
  }

  // Children array (Paragraph, Heading, BlockQuote, etc.)
  if (Array.isArray(node.children)) {
    for (const child of node.children) {
      collectText(child, parts);
    }
  }

  // List items
  if (Array.isArray(node.items)) {
    for (const item of node.items) {
      if (Array.isArray(item.children)) {
        for (const child of item.children) {
          collectText(child, parts);
        }
      }
    }
  }

  // Table rows → cells → children
  if (Array.isArray(node.rows)) {
    for (const row of node.rows) {
      if (Array.isArray(row.cells)) {
        for (const cell of row.cells) {
          if (Array.isArray(cell.children)) {
            for (const child of cell.children) {
              collectText(child, parts);
            }
          }
        }
      }
    }
  }
}

/**
 * Extract flattened Text children descriptors from a RenderNode.
 * Used for inline feature gap checking.
 */
export function extractTextChildren(node) {
  const textChildren = [];
  collectTextChildren(node, textChildren);
  return textChildren;
}

function collectTextChildren(node, output) {
  if (node.type === 'Text') {
    output.push({
      content: node.content ?? '',
      bold: node.bold ?? false,
      italic: node.italic ?? false,
      underline: node.underline ?? false,
      line_through: node.line_through ?? false,
      superscript: node.superscript ?? false,
      subscript: node.subscript ?? false,
    });
    return;
  }

  if (Array.isArray(node.children)) {
    for (const child of node.children) {
      collectTextChildren(child, output);
    }
  }

  if (Array.isArray(node.items)) {
    for (const item of node.items) {
      if (Array.isArray(item.children)) {
        for (const child of item.children) {
          collectTextChildren(child, output);
        }
      }
    }
  }

  if (Array.isArray(node.rows)) {
    for (const row of node.rows) {
      if (Array.isArray(row.cells)) {
        for (const cell of row.cells) {
          if (Array.isArray(cell.children)) {
            for (const child of cell.children) {
              collectTextChildren(child, output);
            }
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Element matching — find a RenderNode that corresponds to an XHTML element
// ---------------------------------------------------------------------------

/**
 * Find the best matching parser node for an XHTML element.
 * Returns { index, node } or null if no match.
 */
export function findBestMatch(element, parserNodes, alreadyMatched) {
  const candidates = [];

  for (let i = 0; i < parserNodes.length; i++) {
    if (alreadyMatched.has(i)) {
      continue;
    }

    const node = parserNodes[i];
    const score = computeMatchScore(element, node);
    if (score > 0) {
      candidates.push({ index: i, node, score });
    }
  }

  if (candidates.length === 0) {
    return null;
  }

  // Sort by score descending, then by DOM order proximity (index) ascending
  candidates.sort((a, b) => b.score - a.score || a.index - b.index);
  return candidates[0];
}

/**
 * Score how well an XHTML element matches a parser node.
 * Returns 0 if incompatible, higher = better match.
 */
export function computeMatchScore(element, parserNode) {
  // Step 1: Block case compatibility check
  if (!isBlockCaseCompatible(element.blockCaseId, parserNode)) {
    return 0;
  }

  let score = 1; // Base score for compatible block case

  // Step 2: For text-bearing elements, check text similarity
  const elementCanonical = canonicalizeText(element.normalizedText);
  const nodeCanonical = parserNode.canonicalText;
  const elementNormalized = normalizeText(element.normalizedText);
  const nodeNormalized = parserNode.normalizedText;

  if (isNonTextElement(element)) {
    // Non-text elements: tag type match already gives base score.
    // Same type in same chapter is enough.
    score += 1;
  } else if (elementCanonical !== '' && nodeCanonical !== '') {
    // Exact canonical text match
    if (elementCanonical === nodeCanonical) {
      score += 10;
    } else if (nodeCanonical.includes(elementCanonical) || elementCanonical.includes(nodeCanonical)) {
      // Partial match — one contains the other
      score += 5;
    }
  } else if (elementCanonical === '' && nodeCanonical === '' &&
             elementNormalized !== '' && nodeNormalized !== '') {
    // Both canonical texts are empty (symbol-only like "***"), fall back to
    // normalizedText comparison to avoid false mismatches
    if (elementNormalized === nodeNormalized) {
      score += 8;
    }
  } else if (elementCanonical === '' && nodeCanonical === '') {
    // Both truly empty — weak match
    score += 1;
  }

  return score;
}

/**
 * Check if an element's block case is compatible with a parser node's type.
 */
function isBlockCaseCompatible(blockCaseId, parserNode) {
  // Direct case ID match
  if (blockCaseId === parserNode.blockCaseId) {
    return true;
  }

  // Compatible mappings (e.g., dt/dd → ParagraphNode)
  const compatibleTypes = COMPATIBLE_RENDER_NODE_TYPES[blockCaseId];
  if (compatibleTypes != null && compatibleTypes.includes(parserNode.renderNodeType)) {
    return true;
  }

  // Heading sub-cases: block.heading.h2 should match any HeadingNode
  if (blockCaseId.startsWith('block.heading.') && parserNode.renderNodeType === 'Heading') {
    return true;
  }

  // List sub-cases: block.list.nested should match ListNode
  if (blockCaseId === 'block.list.nested' && parserNode.renderNodeType === 'List') {
    return true;
  }

  return false;
}

/**
 * Whether an element is non-text (matched by type + position rather than text).
 */
function isNonTextElement(element) {
  return element.tagName === 'hr' || element.tagName === 'img';
}

/**
 * Whether text is whitespace-only (empty or contains only spaces/newlines/tabs).
 * The Rust parser intentionally strips these elements.
 */
function isWhitespaceOnly(text) {
  return text == null || text.trim() === '';
}

// ---------------------------------------------------------------------------
// Feature gap detection
// ---------------------------------------------------------------------------

/**
 * Detect inline and layout feature gaps on a matched element.
 */
function detectFeatureGaps(element, parserNode, chapterIndex, caseCatalog) {
  const gaps = [];

  // Inline feature checks
  for (const featureCaseId of element.featureCaseIds) {
    const check = INLINE_FEATURE_CHECKS[featureCaseId];
    if (check == null) {
      continue;
    }

    const featureStatus = caseCatalog.byId[featureCaseId]?.status;
    if (featureStatus !== 'supported' && featureStatus !== 'partial') {
      continue;
    }

    // Check if any Text child has the expected property
    const hasFeature = parserNode.textChildren.some(
      (tc) => tc[check.property] === check.value,
    );

    if (!hasFeature && parserNode.textChildren.length > 0) {
      gaps.push({
        type: 'feature_gap',
        chapterIndex,
        elementId: element.elementId,
        blockCaseId: element.blockCaseId,
        matchedNodeKind: parserNode.renderNodeType,
        missingFeature: featureCaseId,
        detail: buildFeatureGapDetail(featureCaseId, check),
        hint: buildFeatureGapHint(featureCaseId),
      });
    }
  }

  // Layout align checks
  for (const layoutCaseId of element.layoutCaseIds) {
    const expectedAlign = LAYOUT_ALIGN_CHECKS[layoutCaseId];
    if (expectedAlign == null) {
      continue;
    }

    const layoutStatus = caseCatalog.byId[layoutCaseId]?.status;
    if (layoutStatus !== 'supported' && layoutStatus !== 'partial') {
      continue;
    }

    const actualAlign = parserNode.align;
    if (actualAlign !== expectedAlign) {
      gaps.push({
        type: 'feature_gap',
        chapterIndex,
        elementId: element.elementId,
        blockCaseId: element.blockCaseId,
        matchedNodeKind: parserNode.renderNodeType,
        missingFeature: layoutCaseId,
        detail: `XHTML has ${layoutCaseId} but RenderNode has align=${actualAlign ?? 'null'}`,
        hint: buildFeatureGapHint(layoutCaseId),
      });
    }
  }

  return gaps;
}

// ---------------------------------------------------------------------------
// Hint builders
// ---------------------------------------------------------------------------

const TAG_TO_HANDLER_HINT = {
  table: 'Check html.rs walk_children_of_node() for table handling.',
  blockquote: 'Check html.rs walk_children_of_node() for blockquote handling.',
  pre: 'Check html.rs walk_children_of_node() for <pre> handling.',
  img: 'Check html.rs walk_children_of_node() for <img> handling.',
  hr: 'Check html.rs walk_children_of_node() for <hr> handling.',
  dt: 'Check html.rs walk_children_of_node() for <dt> definition term handling.',
  dd: 'Check html.rs walk_children_of_node() for <dd> definition description handling.',
};

function buildMissingElementHint(element) {
  const tagHint = TAG_TO_HANDLER_HINT[element.tagName];
  if (tagHint) {
    return `Rust parser does not handle <${element.tagName}> in this context. ${tagHint}`;
  }
  if (element.tagName.startsWith('h')) {
    return `Rust parser does not handle <${element.tagName}> in this context. Check html.rs walk_children_of_node() for heading handling.`;
  }
  return `Rust parser does not handle <${element.tagName}> in this context. Check html.rs walk_children_of_node() for ${element.tagName} handling.`;
}

const FEATURE_HINT_MAP = {
  'inline.bold': 'Check html.rs walk_inline_children() for <strong>/<b> tags.',
  'inline.italic': 'Check html.rs walk_inline_children() for <em>/<i> tags.',
  'inline.underline': 'Check html.rs walk_inline_children() for <u>/<ins> tags.',
  'inline.strikethrough': 'Check html.rs walk_inline_children() for <del>/<s> tags.',
  'inline.superscript': 'Check html.rs walk_inline_children() for <sup> tag handling.',
  'inline.subscript': 'Check html.rs walk_inline_children() for <sub> tag handling.',
  'layout.align.center': 'Check html.rs StyleProps text_align extraction.',
  'layout.align.right': 'Check html.rs StyleProps text_align extraction.',
  'layout.align.left': 'Check html.rs StyleProps text_align extraction.',
  'layout.align.justify': 'Check html.rs StyleProps text_align extraction.',
};

function buildFeatureGapHint(featureCaseId) {
  return FEATURE_HINT_MAP[featureCaseId]
    ?? `Check html.rs for ${featureCaseId} handling.`;
}

function buildFeatureGapDetail(featureCaseId, check) {
  const tagMap = {
    'inline.bold': '<strong>/<b>',
    'inline.italic': '<em>/<i>',
    'inline.underline': '<u>/<ins>',
    'inline.strikethrough': '<del>/<s>',
    'inline.superscript': '<sup>',
    'inline.subscript': '<sub>',
  };
  const tag = tagMap[featureCaseId] ?? featureCaseId;
  return `XHTML contains ${tag} child but RenderNode Text children lack ${check.property}=${String(check.value)}`;
}

function buildOverConvertedHint(parserNode) {
  if (parserNode.normalizedText === '') {
    return `Empty ${parserNode.renderNodeType} with no matching XHTML source. Likely generated from whitespace or flattened container.`;
  }
  return `${parserNode.renderNodeType} with text "${excerptText(parserNode.normalizedText, 80)}" has no matching XHTML source. Check html.rs for spurious node generation.`;
}
