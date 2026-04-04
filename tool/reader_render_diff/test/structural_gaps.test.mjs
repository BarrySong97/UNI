import test from 'node:test';
import assert from 'node:assert/strict';

import {
  findStructuralGaps,
  buildParserInventory,
  resolveBlockCaseId,
  extractNodeText,
  extractTextChildren,
  findBestMatch,
  computeMatchScore,
} from '../src/xhtml/find_structural_gaps.mjs';

// ---------------------------------------------------------------------------
// Minimal case catalog for tests
// ---------------------------------------------------------------------------

const caseCatalog = {
  entries: [],
  byId: {
    'block.paragraph': { caseId: 'block.paragraph', status: 'supported' },
    'block.heading.h1': { caseId: 'block.heading.h1', status: 'supported' },
    'block.heading.h2': { caseId: 'block.heading.h2', status: 'supported' },
    'block.heading.h3': { caseId: 'block.heading.h3', status: 'supported' },
    'block.list.ul': { caseId: 'block.list.ul', status: 'supported' },
    'block.list.ol': { caseId: 'block.list.ol', status: 'supported' },
    'block.list.nested': { caseId: 'block.list.nested', status: 'supported' },
    'block.table.basic': { caseId: 'block.table.basic', status: 'supported' },
    'block.blockquote': { caseId: 'block.blockquote', status: 'supported' },
    'block.code.pre': { caseId: 'block.code.pre', status: 'supported' },
    'block.image': { caseId: 'block.image', status: 'partial' },
    'block.horizontal_rule': { caseId: 'block.horizontal_rule', status: 'supported' },
    'block.definition_list.dt': { caseId: 'block.definition_list.dt', status: 'partial' },
    'block.definition_list.dd': { caseId: 'block.definition_list.dd', status: 'partial' },
    'inline.bold': { caseId: 'inline.bold', status: 'supported' },
    'inline.italic': { caseId: 'inline.italic', status: 'supported' },
    'inline.underline': { caseId: 'inline.underline', status: 'supported' },
    'inline.strikethrough': { caseId: 'inline.strikethrough', status: 'supported' },
    'inline.superscript': { caseId: 'inline.superscript', status: 'supported' },
    'inline.subscript': { caseId: 'inline.subscript', status: 'supported' },
    'inline.link': { caseId: 'inline.link', status: 'supported' },
    'layout.align.center': { caseId: 'layout.align.center', status: 'supported' },
    'layout.align.right': { caseId: 'layout.align.right', status: 'supported' },
    'layout.align.left': { caseId: 'layout.align.left', status: 'supported' },
    'layout.align.justify': { caseId: 'layout.align.justify', status: 'supported' },
    'layout.margin': { caseId: 'layout.margin', status: 'supported' },
  },
};

// ---------------------------------------------------------------------------
// Helper: build a minimal XHTML inventory chapter
// ---------------------------------------------------------------------------

function makeXhtmlElement(overrides = {}) {
  return {
    elementId: 'ch0_p_0_abc123',
    domPath: 'body > p',
    tagName: 'p',
    blockCaseId: 'block.paragraph',
    featureCaseIds: [],
    layoutCaseIds: [],
    normalizedText: 'Hello world',
    status: 'supported',
    ...overrides,
  };
}

function makeXhtmlInventory(chapters) {
  return {
    epubPath: 'test.epub',
    chapters: chapters.map((elements, i) => ({
      chapterIndex: i,
      xhtmlPath: `chapter_${i}.xhtml`,
      elements,
      specialCaseCounts: {},
    })),
    summary: {
      totalElements: chapters.reduce((sum, ch) => sum + ch.length, 0),
      byCaseId: {},
    },
  };
}

function makeChapterJson(index, nodes) {
  return { index, title: `Chapter ${index}`, href: `/chapter_${index}.xhtml`, nodes };
}

function makeParagraphNode(text, overrides = {}) {
  return {
    type: 'Paragraph',
    children: [
      {
        type: 'Text',
        content: text,
        bold: false,
        italic: false,
        underline: false,
        line_through: false,
        superscript: false,
        subscript: false,
        font_size_em: 1.0,
        ...overrides,
      },
    ],
    align: 'Left',
    margin_top_em: 0.0,
    margin_bottom_em: 0.0,
    margin_left_em: 0.0,
    margin_right_em: 0.0,
    text_indent_em: 0.0,
    line_height_em: 1.3,
    padding_em: 0.0,
  };
}

function makeHeadingNode(text, level = 1) {
  return {
    type: 'Heading',
    level,
    children: [
      {
        type: 'Text',
        content: text,
        bold: true,
        italic: false,
        underline: false,
        line_through: false,
      },
    ],
    align: 'Center',
  };
}

// ===================================================================
// resolveBlockCaseId
// ===================================================================

test('resolveBlockCaseId: Paragraph → block.paragraph', () => {
  assert.equal(resolveBlockCaseId({ type: 'Paragraph' }), 'block.paragraph');
});

test('resolveBlockCaseId: Heading with level → block.heading.hN', () => {
  assert.equal(resolveBlockCaseId({ type: 'Heading', level: 1 }), 'block.heading.h1');
  assert.equal(resolveBlockCaseId({ type: 'Heading', level: 3 }), 'block.heading.h3');
});

test('resolveBlockCaseId: Heading without level defaults to h1', () => {
  assert.equal(resolveBlockCaseId({ type: 'Heading' }), 'block.heading.h1');
});

test('resolveBlockCaseId: List ordered → block.list.ol', () => {
  assert.equal(resolveBlockCaseId({ type: 'List', ordered: true }), 'block.list.ol');
});

test('resolveBlockCaseId: List unordered → block.list.ul', () => {
  assert.equal(resolveBlockCaseId({ type: 'List', ordered: false }), 'block.list.ul');
});

test('resolveBlockCaseId: Table → block.table.basic', () => {
  assert.equal(resolveBlockCaseId({ type: 'Table' }), 'block.table.basic');
});

test('resolveBlockCaseId: BlockQuote → block.blockquote', () => {
  assert.equal(resolveBlockCaseId({ type: 'BlockQuote' }), 'block.blockquote');
});

test('resolveBlockCaseId: CodeBlock → block.code.pre', () => {
  assert.equal(resolveBlockCaseId({ type: 'CodeBlock' }), 'block.code.pre');
});

test('resolveBlockCaseId: Image → block.image', () => {
  assert.equal(resolveBlockCaseId({ type: 'Image' }), 'block.image');
});

test('resolveBlockCaseId: HorizontalRule → block.horizontal_rule', () => {
  assert.equal(resolveBlockCaseId({ type: 'HorizontalRule' }), 'block.horizontal_rule');
});

test('resolveBlockCaseId: unknown type → null', () => {
  assert.equal(resolveBlockCaseId({ type: 'SomethingElse' }), null);
});

// ===================================================================
// extractNodeText
// ===================================================================

test('extractNodeText: Paragraph with Text children', () => {
  const node = makeParagraphNode('Hello world');
  assert.equal(extractNodeText(node), 'Hello world');
});

test('extractNodeText: Paragraph with multiple Text children', () => {
  const node = {
    type: 'Paragraph',
    children: [
      { type: 'Text', content: 'Hello' },
      { type: 'Text', content: 'world' },
    ],
  };
  assert.equal(extractNodeText(node), 'Hello world');
});

test('extractNodeText: CodeBlock with text property', () => {
  const node = { type: 'CodeBlock', text: 'console.log("hi")' };
  assert.equal(extractNodeText(node), 'console.log("hi")');
});

test('extractNodeText: Image with alt', () => {
  const node = { type: 'Image', alt: 'A description' };
  assert.equal(extractNodeText(node), 'A description');
});

test('extractNodeText: List with items', () => {
  const node = {
    type: 'List',
    ordered: false,
    items: [
      { children: [{ type: 'Text', content: 'Item one' }] },
      { children: [{ type: 'Text', content: 'Item two' }] },
    ],
  };
  assert.equal(extractNodeText(node), 'Item one Item two');
});

test('extractNodeText: Table with rows/cells', () => {
  const node = {
    type: 'Table',
    rows: [
      {
        cells: [
          { children: [{ type: 'Text', content: 'Header' }], col_span: 1, row_span: 1, is_header: true },
          { children: [{ type: 'Text', content: 'Value' }], col_span: 1, row_span: 1, is_header: false },
        ],
      },
    ],
  };
  assert.equal(extractNodeText(node), 'Header Value');
});

test('extractNodeText: HorizontalRule returns empty text', () => {
  const node = { type: 'HorizontalRule' };
  assert.equal(extractNodeText(node), '');
});

test('extractNodeText: BlockQuote with children', () => {
  const node = {
    type: 'BlockQuote',
    children: [
      { type: 'Text', content: 'A wise quote' },
    ],
  };
  assert.equal(extractNodeText(node), 'A wise quote');
});

// ===================================================================
// extractTextChildren
// ===================================================================

test('extractTextChildren: flattens Text nodes from Paragraph', () => {
  const node = {
    type: 'Paragraph',
    children: [
      { type: 'Text', content: 'bold text', bold: true, italic: false, underline: false, line_through: false },
      { type: 'Text', content: 'normal text', bold: false, italic: false, underline: false, line_through: false },
    ],
  };
  const children = extractTextChildren(node);
  assert.equal(children.length, 2);
  assert.equal(children[0].bold, true);
  assert.equal(children[1].bold, false);
});

test('extractTextChildren: collects from List items', () => {
  const node = {
    type: 'List',
    items: [
      { children: [{ type: 'Text', content: 'a', bold: false, italic: true }] },
    ],
  };
  const children = extractTextChildren(node);
  assert.equal(children.length, 1);
  assert.equal(children[0].italic, true);
});

test('extractTextChildren: collects from Table cells', () => {
  const node = {
    type: 'Table',
    rows: [{
      cells: [{
        children: [{ type: 'Text', content: 'cell', bold: true }],
      }],
    }],
  };
  const children = extractTextChildren(node);
  assert.equal(children.length, 1);
  assert.equal(children[0].bold, true);
});

// ===================================================================
// buildParserInventory
// ===================================================================

test('buildParserInventory: builds flat list from chapter JSON', () => {
  const chapterJson = makeChapterJson(0, [
    makeParagraphNode('First paragraph'),
    makeHeadingNode('Title', 2),
    { type: 'HorizontalRule' },
  ]);
  const inventory = buildParserInventory(chapterJson);
  assert.equal(inventory.length, 3);
  assert.equal(inventory[0].blockCaseId, 'block.paragraph');
  assert.equal(inventory[1].blockCaseId, 'block.heading.h2');
  assert.equal(inventory[2].blockCaseId, 'block.horizontal_rule');
});

test('buildParserInventory: handles empty chapter', () => {
  const chapterJson = makeChapterJson(0, []);
  const inventory = buildParserInventory(chapterJson);
  assert.equal(inventory.length, 0);
});

test('buildParserInventory: handles chapter with no nodes key', () => {
  const chapterJson = { index: 0 };
  const inventory = buildParserInventory(chapterJson);
  assert.equal(inventory.length, 0);
});

// ===================================================================
// computeMatchScore
// ===================================================================

test('computeMatchScore: exact text match gets highest score', () => {
  const element = makeXhtmlElement({ normalizedText: 'Hello world' });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Hello world'),
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score >= 11); // 1 base + 10 text match
});

test('computeMatchScore: incompatible block case returns 0', () => {
  const element = makeXhtmlElement({ blockCaseId: 'block.table.basic' });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Hello'),
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.equal(score, 0);
});

test('computeMatchScore: partial text match (containment) gets medium score', () => {
  const element = makeXhtmlElement({ normalizedText: 'Hello world from me' });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Hello world from me and more text'),
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score >= 6); // 1 base + 5 partial
});

test('computeMatchScore: definition_list.dt matches ParagraphNode (compatible)', () => {
  const element = makeXhtmlElement({
    blockCaseId: 'block.definition_list.dt',
    tagName: 'dt',
    normalizedText: 'Term',
  });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Term'),
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score > 0);
});

test('computeMatchScore: heading sub-case matches HeadingNode', () => {
  const element = makeXhtmlElement({
    blockCaseId: 'block.heading.h2',
    tagName: 'h2',
    normalizedText: 'Chapter Title',
  });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    makeHeadingNode('Chapter Title', 2),
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score >= 11);
});

test('computeMatchScore: nested list matches ListNode', () => {
  const element = makeXhtmlElement({
    blockCaseId: 'block.list.nested',
    tagName: 'ul',
    normalizedText: 'Nested item',
  });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    { type: 'List', ordered: false, items: [{ children: [{ type: 'Text', content: 'Nested item' }] }] },
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score > 0);
});

test('computeMatchScore: non-text elements (hr) match with base + type score', () => {
  const element = makeXhtmlElement({
    blockCaseId: 'block.horizontal_rule',
    tagName: 'hr',
    normalizedText: '',
  });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    { type: 'HorizontalRule' },
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score >= 2); // 1 base + 1 non-text
});

test('computeMatchScore: img is non-text element', () => {
  const element = makeXhtmlElement({
    blockCaseId: 'block.image',
    tagName: 'img',
    normalizedText: '',
  });
  const parserNode = buildParserInventory(makeChapterJson(0, [
    { type: 'Image', alt: 'description' },
  ]))[0];
  const score = computeMatchScore(element, parserNode);
  assert.ok(score >= 2);
});

// ===================================================================
// findBestMatch
// ===================================================================

test('findBestMatch: returns best match by text', () => {
  const element = makeXhtmlElement({ normalizedText: 'Second paragraph' });
  const parserNodes = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('First paragraph'),
    makeParagraphNode('Second paragraph'),
    makeParagraphNode('Third paragraph'),
  ]));
  const result = findBestMatch(element, parserNodes, new Set());
  assert.ok(result != null);
  assert.equal(result.index, 1);
});

test('findBestMatch: skips already matched nodes', () => {
  const element = makeXhtmlElement({ normalizedText: 'Same text' });
  const parserNodes = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Same text'),
    makeParagraphNode('Same text'),
  ]));
  const alreadyMatched = new Set([0]);
  const result = findBestMatch(element, parserNodes, alreadyMatched);
  assert.ok(result != null);
  assert.equal(result.index, 1);
});

test('findBestMatch: returns null when no match found', () => {
  const element = makeXhtmlElement({
    blockCaseId: 'block.table.basic',
    tagName: 'table',
    normalizedText: 'Table data',
  });
  const parserNodes = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Paragraph text'),
  ]));
  const result = findBestMatch(element, parserNodes, new Set());
  assert.equal(result, null);
});

test('findBestMatch: prefers exact match over partial', () => {
  const element = makeXhtmlElement({ normalizedText: 'Hello' });
  const parserNodes = buildParserInventory(makeChapterJson(0, [
    makeParagraphNode('Hello world'),
    makeParagraphNode('Hello'),
  ]));
  const result = findBestMatch(element, parserNodes, new Set());
  assert.ok(result != null);
  assert.equal(result.index, 1);
});

// ===================================================================
// findStructuralGaps — missing_element detection
// ===================================================================

test('findStructuralGaps: all elements matched → no gaps', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({ normalizedText: 'Hello world' }),
      makeXhtmlElement({
        elementId: 'ch0_h1_1_def456',
        tagName: 'h1',
        blockCaseId: 'block.heading.h1',
        normalizedText: 'Title',
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Hello world'),
      makeHeadingNode('Title', 1),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.missingElements, 0);
  assert.equal(result.summary.matchedElements, 2);
  assert.equal(result.summary.overConvertedNodes, 0);
  assert.equal(result.summary.gapScore, 0);
});

test('findStructuralGaps: missing supported element produces missing_element gap', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({ normalizedText: 'Hello world' }),
      makeXhtmlElement({
        elementId: 'ch0_table_1_aaa111',
        tagName: 'table',
        blockCaseId: 'block.table.basic',
        domPath: 'body > div > table',
        normalizedText: 'Header Data',
        status: 'supported',
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Hello world'),
      // No Table node — this is the gap
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.missingElements, 1);
  assert.equal(result.summary.matchedElements, 1);

  const gap = result.gaps.find((g) => g.type === 'missing_element');
  assert.ok(gap);
  assert.equal(gap.blockCaseId, 'block.table.basic');
  assert.equal(gap.elementId, 'ch0_table_1_aaa111');
  assert.ok(gap.hint.includes('table'));
});

test('findStructuralGaps: unsupported missing element is NOT a gap', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        elementId: 'ch0_custom_0_xyz',
        tagName: 'custom',
        blockCaseId: 'block.custom_thing',
        normalizedText: 'Unknown',
        status: 'unsupported', // Not supported — should not be flagged
      }),
    ],
  ]);
  const chapterJsons = [makeChapterJson(0, [])];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.missingElements, 0);
  assert.equal(result.gaps.filter((g) => g.type === 'missing_element').length, 0);
});

test('findStructuralGaps: partial status element IS reported as gap', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        elementId: 'ch0_img_0_abc',
        tagName: 'img',
        blockCaseId: 'block.image',
        normalizedText: '',
        status: 'partial',
      }),
    ],
  ]);
  const chapterJsons = [makeChapterJson(0, [])];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.missingElements, 1);
  const gap = result.gaps.find((g) => g.type === 'missing_element');
  assert.ok(gap);
  assert.equal(gap.status, 'partial');
});

test('findStructuralGaps: special.* case is skipped entirely', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        blockCaseId: 'special.flattened_container',
        tagName: 'div',
        normalizedText: '',
        status: 'ignored_by_design',
      }),
    ],
  ]);
  const chapterJsons = [makeChapterJson(0, [])];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.missingElements, 0);
  assert.equal(result.summary.matchedElements, 0);
  // totalXhtmlElements still counts it
  assert.equal(result.summary.totalXhtmlElements, 1);
});

// ===================================================================
// findStructuralGaps — feature_gap detection
// ===================================================================

test('findStructuralGaps: inline.bold feature gap when Text lacks bold=true', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Bold text here',
        featureCaseIds: ['inline.bold'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Bold text here', { bold: false }),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  assert.equal(result.summary.matchedElements, 1);

  const gap = result.gaps.find((g) => g.type === 'feature_gap');
  assert.ok(gap);
  assert.equal(gap.missingFeature, 'inline.bold');
  assert.ok(gap.detail.includes('<strong>/<b>'));
  assert.ok(gap.hint.includes('walk_inline_children'));
});

test('findStructuralGaps: no feature gap when bold is present', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Bold text here',
        featureCaseIds: ['inline.bold'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      {
        type: 'Paragraph',
        children: [
          { type: 'Text', content: 'Bold ', bold: true, italic: false, underline: false, line_through: false },
          { type: 'Text', content: 'text here', bold: false, italic: false, underline: false, line_through: false },
        ],
        align: 'Left',
      },
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 0);
});

test('findStructuralGaps: italic feature gap detection', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Italic text',
        featureCaseIds: ['inline.italic'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Italic text', { italic: false }),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  const gap = result.gaps.find((g) => g.missingFeature === 'inline.italic');
  assert.ok(gap);
});

test('findStructuralGaps: superscript feature gap detection', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'x squared',
        featureCaseIds: ['inline.superscript'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('x squared', { superscript: false }),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  const gap = result.gaps.find((g) => g.missingFeature === 'inline.superscript');
  assert.ok(gap);
  assert.ok(gap.hint.includes('<sup>'));
});

test('findStructuralGaps: multiple inline feature gaps on same element', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Bold and italic',
        featureCaseIds: ['inline.bold', 'inline.italic'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Bold and italic', { bold: false, italic: false }),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 2);
});

test('findStructuralGaps: layout.align.center gap when parser has Left', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Centered text',
        layoutCaseIds: ['layout.align.center'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Centered text'), // default align is Left
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  const gap = result.gaps.find((g) => g.missingFeature === 'layout.align.center');
  assert.ok(gap);
  assert.ok(gap.detail.includes('align=Left'));
  assert.ok(gap.hint.includes('StyleProps'));
});

test('findStructuralGaps: no layout gap when align matches', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Centered text',
        layoutCaseIds: ['layout.align.center'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      { ...makeParagraphNode('Centered text'), align: 'Center' },
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 0);
});

// ===================================================================
// findStructuralGaps — over_converted detection
// ===================================================================

test('findStructuralGaps: unmatched parser node is over_converted', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({ normalizedText: 'Hello world' }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Hello world'),
      makeParagraphNode('Extra fabricated content'),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.overConvertedNodes, 1);

  const gap = result.gaps.find((g) => g.type === 'over_converted');
  assert.ok(gap);
  assert.equal(gap.renderNodeKind, 'Paragraph');
  assert.ok(gap.normalizedText.includes('Extra fabricated'));
});

test('findStructuralGaps: empty over-converted node hint mentions whitespace', () => {
  const inventory = makeXhtmlInventory([[]]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode(''),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.overConvertedNodes, 1);
  const gap = result.gaps.find((g) => g.type === 'over_converted');
  assert.ok(gap.hint.includes('whitespace') || gap.hint.includes('flattened'));
});

// ===================================================================
// Gap score calculation
// ===================================================================

test('findStructuralGaps: gap score formula is correct', () => {
  // 2 missing elements (2*3=6), 1 feature gap (1*1=1), 1 over-converted (1*2=2) → total 9
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({ elementId: 'ch0_p_0_aaa', normalizedText: 'Matched' }),
      makeXhtmlElement({
        elementId: 'ch0_table_1_bbb',
        tagName: 'table',
        blockCaseId: 'block.table.basic',
        normalizedText: 'Table data',
        status: 'supported',
      }),
      makeXhtmlElement({
        elementId: 'ch0_bq_2_ccc',
        tagName: 'blockquote',
        blockCaseId: 'block.blockquote',
        normalizedText: 'Quote',
        status: 'supported',
      }),
      makeXhtmlElement({
        elementId: 'ch0_p_3_ddd',
        normalizedText: 'Has bold',
        featureCaseIds: ['inline.bold'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [
      makeParagraphNode('Matched'),
      // No Table → missing (1)
      // No BlockQuote → missing (2)
      makeParagraphNode('Has bold', { bold: false }), // Feature gap (1)
      makeParagraphNode('Fabricated'), // Over-converted (1)
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.missingElements, 2);
  assert.equal(result.summary.featureGaps, 1);
  assert.equal(result.summary.overConvertedNodes, 1);
  assert.equal(result.summary.gapScore, 2 * 3 + 1 * 1 + 1 * 2);
});

// ===================================================================
// Multi-chapter support
// ===================================================================

test('findStructuralGaps: works across multiple chapters', () => {
  const inventory = makeXhtmlInventory([
    [makeXhtmlElement({ normalizedText: 'Chapter 0 text' })],
    [makeXhtmlElement({
      elementId: 'ch1_p_0_eee',
      normalizedText: 'Chapter 1 text',
    })],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Chapter 0 text')]),
    makeChapterJson(1, [makeParagraphNode('Chapter 1 text')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.totalXhtmlElements, 2);
  assert.equal(result.summary.matchedElements, 2);
  assert.equal(result.summary.missingElements, 0);
});

test('findStructuralGaps: missing chapter JSON treats all elements as missing', () => {
  const inventory = makeXhtmlInventory([
    [makeXhtmlElement({ normalizedText: 'Chapter 0 text' })],
    [makeXhtmlElement({
      elementId: 'ch1_p_0_fff',
      normalizedText: 'Chapter 1 text',
    })],
  ]);
  // Only provide chapter 0 JSON
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Chapter 0 text')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.matchedElements, 1);
  assert.equal(result.summary.missingElements, 1);
});

// ===================================================================
// Edge cases
// ===================================================================

test('findStructuralGaps: empty inventory and empty chapter', () => {
  const inventory = makeXhtmlInventory([[]]);
  const chapterJsons = [makeChapterJson(0, [])];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.totalXhtmlElements, 0);
  assert.equal(result.summary.matchedElements, 0);
  assert.equal(result.summary.missingElements, 0);
  assert.equal(result.summary.featureGaps, 0);
  assert.equal(result.summary.overConvertedNodes, 0);
  assert.equal(result.summary.gapScore, 0);
  assert.equal(result.gaps.length, 0);
});

test('findStructuralGaps: no chapters at all', () => {
  const inventory = makeXhtmlInventory([]);
  const chapterJsons = [];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.totalXhtmlElements, 0);
  assert.equal(result.summary.gapScore, 0);
});

test('findStructuralGaps: text with different whitespace still matches', () => {
  const inventory = makeXhtmlInventory([
    [makeXhtmlElement({ normalizedText: 'Hello   world' })],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Hello world')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  // canonicalizeText strips non-alphanumeric and lowercases, so these should match
  assert.equal(result.summary.matchedElements, 1);
  assert.equal(result.summary.missingElements, 0);
});

test('findStructuralGaps: text with different case still matches via canonicalize', () => {
  const inventory = makeXhtmlInventory([
    [makeXhtmlElement({ normalizedText: 'HELLO WORLD' })],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('hello world')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.matchedElements, 1);
});

test('findStructuralGaps: definition list dt matches ParagraphNode', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        elementId: 'ch0_dt_0_ggg',
        tagName: 'dt',
        blockCaseId: 'block.definition_list.dt',
        normalizedText: 'Definition term',
        status: 'partial',
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Definition term')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.matchedElements, 1);
  assert.equal(result.summary.missingElements, 0);
});

// ===================================================================
// Hint content validation
// ===================================================================

test('missing_element hint references table handling for table gaps', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        elementId: 'ch0_table_0_hhh',
        tagName: 'table',
        blockCaseId: 'block.table.basic',
        normalizedText: 'Data',
        status: 'supported',
      }),
    ],
  ]);
  const chapterJsons = [makeChapterJson(0, [])];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  const gap = result.gaps[0];
  assert.ok(gap.hint.includes('table'));
  assert.ok(gap.hint.includes('html.rs'));
});

test('missing_element hint references blockquote handling', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        elementId: 'ch0_blockquote_0_iii',
        tagName: 'blockquote',
        blockCaseId: 'block.blockquote',
        normalizedText: 'Quote',
        status: 'supported',
      }),
    ],
  ]);
  const chapterJsons = [makeChapterJson(0, [])];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  const gap = result.gaps[0];
  assert.ok(gap.hint.includes('blockquote'));
});

test('feature gap hint for inline.bold references walk_inline_children', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Bold text',
        featureCaseIds: ['inline.bold'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Bold text', { bold: false })]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  const gap = result.gaps.find((g) => g.type === 'feature_gap');
  assert.ok(gap.hint.includes('walk_inline_children'));
  assert.ok(gap.hint.includes('<strong>/<b>'));
});

test('feature gap hint for layout.align references StyleProps', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Right aligned',
        layoutCaseIds: ['layout.align.right'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Right aligned')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  const gap = result.gaps.find((g) => g.type === 'feature_gap');
  assert.ok(gap.hint.includes('StyleProps'));
});

test('over_converted hint for non-empty node mentions spurious generation', () => {
  const inventory = makeXhtmlInventory([[]]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Spurious text')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  const gap = result.gaps.find((g) => g.type === 'over_converted');
  assert.ok(gap.hint.includes('spurious'));
});

// ===================================================================
// Feature gap for inline features not in INLINE_FEATURE_CHECKS (e.g. link)
// ===================================================================

test('findStructuralGaps: inline.link is not checked as feature gap (no property mapping)', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Link text',
        featureCaseIds: ['inline.link'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Link text')]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  // inline.link has no property check in INLINE_FEATURE_CHECKS, so no gap
  assert.equal(result.summary.featureGaps, 0);
});

// ===================================================================
// Full integration test
// ===================================================================

test('full integration: realistic chapter with mixed gaps', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        elementId: 'ch0_h1_0_aaa',
        tagName: 'h1',
        blockCaseId: 'block.heading.h1',
        normalizedText: 'Introduction',
        status: 'supported',
      }),
      makeXhtmlElement({
        elementId: 'ch0_p_1_bbb',
        normalizedText: 'Normal paragraph text.',
        featureCaseIds: ['inline.bold'],
      }),
      makeXhtmlElement({
        elementId: 'ch0_p_2_ccc',
        normalizedText: 'Centered paragraph.',
        layoutCaseIds: ['layout.align.center'],
      }),
      makeXhtmlElement({
        elementId: 'ch0_table_3_ddd',
        tagName: 'table',
        blockCaseId: 'block.table.basic',
        normalizedText: 'Table data here',
        status: 'supported',
      }),
      makeXhtmlElement({
        elementId: 'ch0_hr_4_eee',
        tagName: 'hr',
        blockCaseId: 'block.horizontal_rule',
        normalizedText: '',
        status: 'supported',
      }),
    ],
  ]);

  const chapterJsons = [
    makeChapterJson(0, [
      makeHeadingNode('Introduction', 1),
      // Paragraph with bold=false (feature gap for inline.bold)
      makeParagraphNode('Normal paragraph text.', { bold: false }),
      // Centered paragraph but parser says Left (feature gap for layout.align.center)
      makeParagraphNode('Centered paragraph.'),
      // No Table node → missing_element
      { type: 'HorizontalRule' },
      // Extra empty paragraph → over_converted
      makeParagraphNode(''),
    ]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });

  // Check summary
  assert.equal(result.summary.totalXhtmlElements, 5);
  assert.equal(result.summary.matchedElements, 4); // h1, p(bold), p(centered), hr
  assert.equal(result.summary.missingElements, 1); // table
  assert.equal(result.summary.featureGaps, 2); // bold gap + center alignment gap
  assert.equal(result.summary.overConvertedNodes, 1); // empty paragraph

  // Check gap score: 1*3 + 2*1 + 1*2 = 7
  assert.equal(result.summary.gapScore, 7);

  // Verify gap types
  const gapTypes = result.gaps.map((g) => g.type).sort();
  assert.deepEqual(gapTypes, ['feature_gap', 'feature_gap', 'missing_element', 'over_converted']);

  // Verify missing_element
  const missing = result.gaps.find((g) => g.type === 'missing_element');
  assert.equal(missing.blockCaseId, 'block.table.basic');

  // Verify feature gaps
  const featureGaps = result.gaps.filter((g) => g.type === 'feature_gap');
  const featureNames = featureGaps.map((g) => g.missingFeature).sort();
  assert.deepEqual(featureNames, ['inline.bold', 'layout.align.center']);

  // Verify over_converted
  const overConverted = result.gaps.find((g) => g.type === 'over_converted');
  assert.equal(overConverted.renderNodeKind, 'Paragraph');
});

// ===================================================================
// Underline, strikethrough, subscript feature gap detection
// ===================================================================

test('findStructuralGaps: underline feature gap', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Underlined text',
        featureCaseIds: ['inline.underline'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Underlined text', { underline: false })]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  const gap = result.gaps.find((g) => g.missingFeature === 'inline.underline');
  assert.ok(gap);
});

test('findStructuralGaps: strikethrough feature gap', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'Struck text',
        featureCaseIds: ['inline.strikethrough'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('Struck text', { line_through: false })]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  const gap = result.gaps.find((g) => g.missingFeature === 'inline.strikethrough');
  assert.ok(gap);
});

test('findStructuralGaps: subscript feature gap', () => {
  const inventory = makeXhtmlInventory([
    [
      makeXhtmlElement({
        normalizedText: 'H2O',
        featureCaseIds: ['inline.subscript'],
      }),
    ],
  ]);
  const chapterJsons = [
    makeChapterJson(0, [makeParagraphNode('H2O', { subscript: false })]),
  ];

  const result = findStructuralGaps({ xhtmlInventory: inventory, chapterJsons, caseCatalog });
  assert.equal(result.summary.featureGaps, 1);
  const gap = result.gaps.find((g) => g.missingFeature === 'inline.subscript');
  assert.ok(gap);
});
