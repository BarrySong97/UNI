import test from 'node:test';
import assert from 'node:assert/strict';

import { parseXhtmlDom } from '../src/xhtml/parse_xhtml_dom.mjs';
import { buildChapterInventory } from '../src/xhtml/build_xhtml_inventory.mjs';

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
    'block.heading.h4': { caseId: 'block.heading.h4', status: 'supported' },
    'block.heading.h5': { caseId: 'block.heading.h5', status: 'supported' },
    'block.heading.h6': { caseId: 'block.heading.h6', status: 'supported' },
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
  },
};

function buildFromHtml(bodyHtml, chapterIndex = 0) {
  const xhtml = `<html><body>${bodyHtml}</body></html>`;
  return buildChapterInventory({
    chapterIndex,
    xhtmlPath: 'test.xhtml',
    xhtmlContent: xhtml,
    caseCatalog,
  });
}

// ===================================================================
// DOM parsing
// ===================================================================

test('parseXhtmlDom returns a document with a body', () => {
  const doc = parseXhtmlDom('<html><body><p>Hello</p></body></html>');
  assert.ok(doc);
  assert.ok(doc.body || doc.querySelector('body'));
  const p = doc.querySelector('p');
  assert.ok(p);
  assert.equal(p.textContent, 'Hello');
});

// ===================================================================
// Block-level tag mapping
// ===================================================================

test('p maps to block.paragraph', () => {
  const result = buildFromHtml('<p>Hello world</p>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.paragraph');
  assert.equal(result.elements[0].tagName, 'p');
});

test('h1 through h6 map to block.heading.*', () => {
  const html = '<h1>H1</h1><h2>H2</h2><h3>H3</h3><h4>H4</h4><h5>H5</h5><h6>H6</h6>';
  const result = buildFromHtml(html);
  assert.equal(result.elements.length, 6);
  for (let i = 0; i < 6; i++) {
    assert.equal(result.elements[i].blockCaseId, `block.heading.h${i + 1}`);
    assert.equal(result.elements[i].tagName, `h${i + 1}`);
  }
});

test('ul maps to block.list.ul (top-level)', () => {
  const result = buildFromHtml('<ul><li>Item</li></ul>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.list.ul');
});

test('ol maps to block.list.ol (top-level)', () => {
  const result = buildFromHtml('<ol><li>Item</li></ol>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.list.ol');
});

test('nested ul inside li maps to block.list.nested', () => {
  const result = buildFromHtml('<ul><li>Top<ul><li>Nested</li></ul></li></ul>');
  // First element is the outer ul (top-level), second is the inner ul (nested)
  assert.equal(result.elements.length, 2);
  assert.equal(result.elements[0].blockCaseId, 'block.list.ul');
  assert.equal(result.elements[1].blockCaseId, 'block.list.nested');
});

test('table maps to block.table.basic', () => {
  const result = buildFromHtml('<table><tr><td>Cell</td></tr></table>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.table.basic');
});

test('blockquote maps to block.blockquote', () => {
  const result = buildFromHtml('<blockquote>Quote text</blockquote>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.blockquote');
});

test('pre maps to block.code.pre', () => {
  const result = buildFromHtml('<pre>code here</pre>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.code.pre');
});

test('img maps to block.image', () => {
  const result = buildFromHtml('<img src="pic.jpg" alt="A picture" />');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.image');
  assert.equal(result.elements[0].status, 'partial');
});

test('hr maps to block.horizontal_rule', () => {
  const result = buildFromHtml('<hr />');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.horizontal_rule');
});

test('dt and dd map to block.definition_list.*', () => {
  const result = buildFromHtml('<dl><dt>Term</dt><dd>Definition</dd></dl>');
  assert.equal(result.elements.length, 2);
  assert.equal(result.elements[0].blockCaseId, 'block.definition_list.dt');
  assert.equal(result.elements[1].blockCaseId, 'block.definition_list.dd');
});

// ===================================================================
// Inline feature detection
// ===================================================================

test('bold detection (strong and b)', () => {
  const result = buildFromHtml('<p><strong>bold</strong> and <b>also bold</b></p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.bold'), true);
});

test('italic detection (em, i, cite, dfn)', () => {
  const result = buildFromHtml('<p><em>a</em> <i>b</i> <cite>c</cite> <dfn>d</dfn></p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.italic'), true);
});

test('underline detection (u, ins)', () => {
  const result = buildFromHtml('<p><u>underlined</u> <ins>inserted</ins></p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.underline'), true);
});

test('strikethrough detection (del, s)', () => {
  const result = buildFromHtml('<p><del>deleted</del> <s>struck</s></p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.strikethrough'), true);
});

test('link detection (a)', () => {
  const result = buildFromHtml('<p><a href="#">Click me</a></p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.link'), true);
});

test('superscript and subscript', () => {
  const result = buildFromHtml('<p>x<sup>2</sup> + y<sub>1</sub></p>');
  const features = result.elements[0].featureCaseIds;
  assert.equal(features.includes('inline.superscript'), true);
  assert.equal(features.includes('inline.subscript'), true);
});

test('small and mark', () => {
  const result = buildFromHtml('<p><small>fine print</small> <mark>highlighted</mark></p>');
  const features = result.elements[0].featureCaseIds;
  assert.equal(features.includes('inline.small'), true);
  assert.equal(features.includes('inline.mark'), true);
});

test('inline code (not inside pre)', () => {
  const result = buildFromHtml('<p>Use <code>console.log</code> for debugging</p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.inline_code'), true);
});

test('code inside pre is NOT flagged as inline.inline_code', () => {
  const result = buildFromHtml('<pre><code>function foo() {}</code></pre>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.inline_code'), false);
});

test('line break detection', () => {
  const result = buildFromHtml('<p>Line one<br/>Line two</p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.line_break'), true);
});

test('inline image inside block', () => {
  const result = buildFromHtml('<p>Text <img src="icon.png" alt="icon" /> more text</p>');
  assert.equal(result.elements[0].featureCaseIds.includes('inline.inline_image_alt_fallback'), true);
});

test('nested inline features (bold inside italic)', () => {
  const result = buildFromHtml('<p><em><strong>bold italic</strong></em></p>');
  const features = result.elements[0].featureCaseIds;
  assert.equal(features.includes('inline.bold'), true);
  assert.equal(features.includes('inline.italic'), true);
});

// ===================================================================
// Layout feature detection from inline styles
// ===================================================================

test('text-align center from inline style', () => {
  const result = buildFromHtml('<p style="text-align: center;">Centered</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.center'), true);
});

test('text-align right from inline style', () => {
  const result = buildFromHtml('<p style="text-align: right;">Right</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.right'), true);
});

test('text-align justify from inline style', () => {
  const result = buildFromHtml('<p style="text-align: justify;">Justified</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.justify'), true);
});

test('text-align left from inline style', () => {
  const result = buildFromHtml('<p style="text-align: left;">Left</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.left'), true);
});

test('margin from inline style', () => {
  const result = buildFromHtml('<p style="margin-top: 10px;">Margined</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.margin'), true);
});

test('blockquote has default margin (element-level)', () => {
  const result = buildFromHtml('<blockquote>Quote</blockquote>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.margin'), true);
});

test('padding from inline style', () => {
  const result = buildFromHtml('<p style="padding: 5px;">Padded</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.padding'), true);
});

test('text-indent from inline style', () => {
  const result = buildFromHtml('<p style="text-indent: 2em;">Indented</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.text_indent'), true);
});

test('line-height from inline style', () => {
  const result = buildFromHtml('<p style="line-height: 1.5em;">Spaced</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.line_height'), true);
});

test('text color from inline style', () => {
  const result = buildFromHtml('<p style="color: red;">Colored</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.text_color'), true);
});

test('background color from inline style', () => {
  const result = buildFromHtml('<p style="background-color: yellow;">Highlighted</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.background_color'), true);
});

test('background shorthand detected as background_color', () => {
  const result = buildFromHtml('<p style="background: #f0f0f0;">BG</p>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.background_color'), true);
});

test('list style type from inline style', () => {
  const result = buildFromHtml('<ul style="list-style-type: circle;"><li>Item</li></ul>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.list_style.circle'), true);
});

test('image width hint from inline style', () => {
  const result = buildFromHtml('<img src="pic.jpg" style="width: 50%;" />');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.image.width_hint'), true);
});

test('image width hint from width attribute', () => {
  const result = buildFromHtml('<img src="pic.jpg" width="200" />');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.image.width_hint'), true);
});

// ===================================================================
// Table sub-cases
// ===================================================================

test('table caption detection', () => {
  const result = buildFromHtml('<table><caption>Title</caption><tr><td>Cell</td></tr></table>');
  assert.equal(result.elements[0].layoutCaseIds.includes('block.table.caption'), true);
});

test('table header row detection', () => {
  const result = buildFromHtml('<table><tr><th>Header</th></tr><tr><td>Cell</td></tr></table>');
  assert.equal(result.elements[0].layoutCaseIds.includes('block.table.header_row'), true);
});

test('table colspan detection', () => {
  const result = buildFromHtml('<table><tr><td colspan="2">Wide</td></tr></table>');
  assert.equal(result.elements[0].layoutCaseIds.includes('block.table.colspan'), true);
});

test('table rowspan detection', () => {
  const result = buildFromHtml('<table><tr><td rowspan="3">Tall</td></tr></table>');
  assert.equal(result.elements[0].layoutCaseIds.includes('block.table.rowspan'), true);
});

test('colspan=1 does NOT trigger block.table.colspan', () => {
  const result = buildFromHtml('<table><tr><td colspan="1">Normal</td></tr></table>');
  assert.equal(result.elements[0].layoutCaseIds.includes('block.table.colspan'), false);
});

// ===================================================================
// Special case detection
// ===================================================================

test('div, section, article are counted as flattened containers', () => {
  const result = buildFromHtml('<div><section><article><p>Deep</p></article></section></div>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.paragraph');
  // body (from wrapper) + div + section + article = 4
  assert.equal(result.specialCaseCounts['special.flattened_container'], 4);
});

test('span is counted as flattened container', () => {
  const result = buildFromHtml('<span><p>Inside span</p></span>');
  // body (from wrapper) + span = 2
  assert.equal(result.specialCaseCounts['special.flattened_container'], 2);
  assert.equal(result.elements.length, 1);
});

test('script, style are counted as discarded', () => {
  const result = buildFromHtml('<script>alert(1)</script><style>body{}</style><p>Text</p>');
  assert.equal(result.specialCaseCounts['special.discarded_nonreading_content'], 2);
  assert.equal(result.elements.length, 1);
});

test('display:none elements are counted and skipped', () => {
  const result = buildFromHtml('<p style="display: none;">Hidden</p><p>Visible</p>');
  assert.equal(result.specialCaseCounts['special.display_none'], 1);
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].normalizedText, 'Visible');
});

test('position:absolute elements are counted and skipped', () => {
  const result = buildFromHtml('<p style="position: absolute;">Absolute</p><p>Normal</p>');
  assert.equal(result.specialCaseCounts['special.out_of_flow_absolute_fixed'], 1);
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].normalizedText, 'Normal');
});

test('position:fixed elements are counted and skipped', () => {
  const result = buildFromHtml('<p style="position: fixed;">Fixed</p><p>Normal</p>');
  assert.equal(result.specialCaseCounts['special.out_of_flow_absolute_fixed'], 1);
  assert.equal(result.elements.length, 1);
});

test('discarded elements are not descended into', () => {
  const result = buildFromHtml('<form><p>Should not appear</p></form><p>Real</p>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].normalizedText, 'Real');
  assert.equal(result.specialCaseCounts['special.discarded_nonreading_content'], 1);
});

// ===================================================================
// Stable element ID generation
// ===================================================================

test('element IDs follow the expected format', () => {
  const result = buildFromHtml('<p>Hello</p>');
  const id = result.elements[0].elementId;
  // Format: ch{chapterIndex}_{tagName}_{domOrderIndex}_{contentHash6chars}
  assert.match(id, /^ch0_p_0_[0-9a-f]{6}$/);
});

test('element IDs are deterministic', () => {
  const result1 = buildFromHtml('<p>Same content</p>');
  const result2 = buildFromHtml('<p>Same content</p>');
  assert.equal(result1.elements[0].elementId, result2.elements[0].elementId);
});

test('different content produces different element IDs', () => {
  const result1 = buildFromHtml('<p>Content A</p>');
  const result2 = buildFromHtml('<p>Content B</p>');
  assert.notEqual(result1.elements[0].elementId, result2.elements[0].elementId);
});

test('chapter index is reflected in element ID', () => {
  const result = buildFromHtml('<p>Text</p>', 5);
  assert.match(result.elements[0].elementId, /^ch5_p_/);
});

// ===================================================================
// Text normalization
// ===================================================================

test('text is normalized (whitespace collapsed, trimmed)', () => {
  const result = buildFromHtml('<p>  Hello   World  \n  </p>');
  assert.equal(result.elements[0].normalizedText, 'Hello World');
});

test('non-breaking spaces are normalized', () => {
  const result = buildFromHtml('<p>Hello\u00A0World</p>');
  assert.equal(result.elements[0].normalizedText, 'Hello World');
});

// ===================================================================
// DOM path building
// ===================================================================

test('domPath is built correctly for simple structure', () => {
  const result = buildFromHtml('<p>First</p><p>Second</p>');
  // Both p tags are siblings, so they should get nth-of-type indices
  assert.ok(result.elements[0].domPath.includes('p'));
  assert.ok(result.elements[1].domPath.includes('p'));
});

// ===================================================================
// Full inventory integration test
// ===================================================================

test('full chapter inventory from realistic XHTML', () => {
  const xhtml = `
    <html>
      <head><title>Chapter One</title></head>
      <body>
        <div class="chapter">
          <h1>Introduction</h1>
          <p>This is a <strong>bold</strong> and <em>italic</em> paragraph.</p>
          <p style="text-align: center; color: blue;">Centered blue text.</p>
          <blockquote>A famous quote.</blockquote>
          <ul>
            <li>Item one</li>
            <li>Item two
              <ul>
                <li>Nested item</li>
              </ul>
            </li>
          </ul>
          <table>
            <caption>Data Table</caption>
            <tr><th>Name</th><th>Value</th></tr>
            <tr><td>A</td><td>1</td></tr>
          </table>
          <hr />
          <pre><code>console.log("hi");</code></pre>
          <p>Final paragraph with a <a href="#">link</a>.</p>
          <script>var x = 1;</script>
          <img src="cover.jpg" alt="Cover" />
        </div>
      </body>
    </html>
  `;

  const result = buildChapterInventory({
    chapterIndex: 0,
    xhtmlPath: 'chapter1.xhtml',
    xhtmlContent: xhtml,
    caseCatalog,
  });

  // Verify structure
  assert.equal(result.chapterIndex, 0);
  assert.equal(result.xhtmlPath, 'chapter1.xhtml');

  // Count block elements: h1, p, p(centered), blockquote, ul, nested ul, table, hr, pre, p(final), img
  assert.equal(result.elements.length, 11);

  // Verify specific elements
  const h1 = result.elements.find((e) => e.blockCaseId === 'block.heading.h1');
  assert.ok(h1);
  assert.equal(h1.normalizedText, 'Introduction');

  const boldParagraph = result.elements.find((e) =>
    e.blockCaseId === 'block.paragraph' && e.featureCaseIds.includes('inline.bold'),
  );
  assert.ok(boldParagraph);
  assert.equal(boldParagraph.featureCaseIds.includes('inline.italic'), true);

  const centeredP = result.elements.find((e) =>
    e.layoutCaseIds.includes('layout.align.center'),
  );
  assert.ok(centeredP);
  assert.equal(centeredP.layoutCaseIds.includes('layout.text_color'), true);

  const bq = result.elements.find((e) => e.blockCaseId === 'block.blockquote');
  assert.ok(bq);
  assert.equal(bq.layoutCaseIds.includes('layout.margin'), true);

  const topUl = result.elements.find((e) => e.blockCaseId === 'block.list.ul');
  assert.ok(topUl);
  const nestedList = result.elements.find((e) => e.blockCaseId === 'block.list.nested');
  assert.ok(nestedList);

  const table = result.elements.find((e) => e.blockCaseId === 'block.table.basic');
  assert.ok(table);
  assert.equal(table.layoutCaseIds.includes('block.table.caption'), true);
  assert.equal(table.layoutCaseIds.includes('block.table.header_row'), true);

  const hr = result.elements.find((e) => e.blockCaseId === 'block.horizontal_rule');
  assert.ok(hr);

  const pre = result.elements.find((e) => e.blockCaseId === 'block.code.pre');
  assert.ok(pre);
  // code inside pre should NOT produce inline.inline_code
  assert.equal(pre.featureCaseIds.includes('inline.inline_code'), false);

  const linkParagraph = result.elements.find((e) =>
    e.blockCaseId === 'block.paragraph' && e.featureCaseIds.includes('inline.link'),
  );
  assert.ok(linkParagraph);

  const img = result.elements.find((e) => e.blockCaseId === 'block.image');
  assert.ok(img);

  // Special cases
  // body + div.chapter = 2 flattened containers (walker starts at body, not html)
  assert.equal(result.specialCaseCounts['special.flattened_container'], 2);
  assert.equal(result.specialCaseCounts['special.discarded_nonreading_content'], 1); // script

  // All elements have proper IDs
  for (const element of result.elements) {
    assert.match(element.elementId, /^ch0_[a-z0-9]+_\d+_[0-9a-f]{6}$/);
  }
});

test('empty body produces no elements', () => {
  const result = buildFromHtml('');
  assert.equal(result.elements.length, 0);
  // body itself is a flattened container
  assert.equal(result.specialCaseCounts['special.flattened_container'], 1);
});

test('no inline style produces no layout features for simple p', () => {
  const result = buildFromHtml('<p>Plain text</p>');
  assert.deepEqual(result.elements[0].layoutCaseIds, []);
});

test('center element propagates text-align center to child blocks', () => {
  const result = buildFromHtml('<center><p>Centered text</p></center>');
  assert.equal(result.elements.length, 1);
  assert.equal(result.elements[0].blockCaseId, 'block.paragraph');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.center'), true);
});

test('center element propagation is overridden by explicit inline style', () => {
  const result = buildFromHtml('<center><p style="text-align: right;">Right text</p></center>');
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.right'), true);
  assert.equal(result.elements[0].layoutCaseIds.includes('layout.align.center'), false);
});
