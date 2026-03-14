# EPUB Element Mapping: HTML/CSS → Rust → Flutter

> Full pipeline mapping for the Canvas-based EPUB reader.
>
> **Pipeline**: EPUB HTML/CSS → Rust parser (`html.rs` / `css.rs`) → `RenderNode` JSON → Flutter `LayoutElement` → `CustomPainter` Canvas

---

## 1. HTML Tags

### 1.1 Block-Level Elements


| HTML Tag                          | Rust Behavior                         | RenderNode                | Flutter Rendering                                   | Status    |
| --------------------------------- | ------------------------------------- | ------------------------- | --------------------------------------------------- | --------- |
| `<p>`                             | `collect_inline` → Paragraph          | `Paragraph`               | `ParagraphLayouter` → `TextPainter` on canvas       | Supported |
| `<h1>`–`<h6>`                     | `collect_inline` → Heading            | `Heading`                 | Heading scale (2.0–0.875em), **always bold** (hardcoded in `text_span_builder.dart`), widow prevention | Supported |
| `<blockquote>`                    | Walk children, `italic = true` hardcoded on context (not CSS-driven); `BlockQuote` RenderNode has no margin fields — margins hardcoded in Flutter | `BlockQuote`              | Left indent 2.0em, right margin 1.0em               | Partial |
| `<pre>`                           | `.text().collect()` — strips all child element styling (e.g. `<code><span>`) | `CodeBlock`               | Font 0.85em, gray background, padding 0.5em; **child element formatting lost** | Partial |
| `<ol>`                            | `collect_list_items` (only direct `<li>` children) | `List { ordered: true }`  | Numbered prefix ("1. ", "2. "...), indent 1.5em; **nested lists broken** | Partial |
| `<ul>`                            | `collect_list_items` (only direct `<li>` children) | `List { ordered: false }` | Bullet prefix ("• "), indent 1.5em; **nested lists broken** | Partial |
| `<li>`                            | `collect_inline` → inline walker; block children (`<p>`, `<div>`, nested `<ul>/<ol>`) fall to `_ =>` catch-all | `Paragraph` (inside List) | Block children flattened to inline text, nested list structure lost | Partial |
| `<table>`                         | `collect_table_rows`                  | `Table`                   | Equal-width columns, per-row height; oversized rows continue across pages | Partial   |
| `<tr>`                            | Inside `collect_table_rows_recursive` | Part of `TableRow`        | Row-by-row layout                                   | Supported |
| `<td>` / `<th>`                   | `collect_table_cells`                 | `TableCell`               | Cell padding, background, border                    | Partial   |
| `<thead>` / `<tbody>` / `<tfoot>` | Recursive pass-through                | —                         | Flattened into row list                             | Supported |
| `<caption>`                       | Parsed into `Table.caption` when present in exported JSON | `Table.caption`           | Rendered as centered paragraph before table         | Supported |
| `<colgroup>` / `<col>`            | `walk_children_of_node` (fallback)    | —                         | Ignored, no column width hints used                 | Missing   |
| `<figure>`                        | Walk children (flatten)               | —                         | Children rendered directly, no container styling    | Partial   |
| `<figcaption>`                    | Walk children (flatten)               | —                         | Rendered as plain text, no caption styling          | Partial   |
| `<hr>`                            | Direct map                            | `HorizontalRule`          | 1px line at 30% opacity of text color               | Supported |
| `<br>`                            | Direct map                            | `LineBreak`               | `cursorY += 0.5 * baseFontSize`                     | Supported |
| `<div>`                           | Flatten (keep children)               | —                         | Children promoted to parent level                   | Supported |
| `<section>`                       | Flatten                               | —                         | Children promoted                                   | Supported |
| `<article>`                       | Flatten                               | —                         | Children promoted                                   | Supported |
| `<main>`                          | Flatten                               | —                         | Children promoted                                   | Supported |
| `<header>`                        | Flatten                               | —                         | Children promoted                                   | Supported |
| `<footer>`                        | Flatten                               | —                         | Children promoted                                   | Supported |
| `<nav>`                           | Flatten                               | —                         | Children promoted                                   | Supported |
| `<aside>`                         | Flatten                               | —                         | Children promoted                                   | Supported |
| `<address>`                       | Not handled (fallback `_ =>`)         | —                         | Walk children, no styling                           | Missing   |
| `<dl>`                            | Not handled (fallback `_ =>`)         | —                         | Children walked, structure lost                     | Missing   |
| `<dt>`                            | Not handled (fallback `_ =>`)         | —                         | Rendered as plain text                              | Missing   |
| `<dd>`                            | Not handled (fallback `_ =>`)         | —                         | Rendered as plain text, no indent                   | Missing   |
| `<details>`                       | Not handled (fallback `_ =>`)         | —                         | Content always visible, not collapsible             | Missing   |
| `<summary>`                       | Not handled (fallback `_ =>`)         | —                         | Rendered as plain text                              | Missing   |
| `<fieldset>`                      | Not handled (fallback `_ =>`)         | —                         | Group semantics and border/legend behavior lost     | Missing   |
| `<legend>`                        | Not handled (fallback `_ =>`)         | —                         | Rendered as plain text, no legend semantics         | Missing   |
| `<meter>`                         | Not handled (fallback `_ =>`)         | —                         | Value gauge not rendered                             | Missing   |
| `<progress>`                      | Not handled (fallback `_ =>`)         | —                         | Progress indicator not rendered                      | Missing   |


### 1.2 Inline Elements


| HTML Tag                   | Rust Behavior                                      | TextNode Fields Set | Flutter TextStyle                      | Status    |
| -------------------------- | -------------------------------------------------- | ------------------- | -------------------------------------- | --------- |
| `<strong>` / `<b>`         | `is_bold_tag` → `bold = true`                      | `bold: true`        | `FontWeight.bold`                      | Supported |
| `<em>` / `<i>`             | `is_italic_tag` → `italic = true`                  | `italic: true`      | `FontStyle.italic`                     | Supported |
| `<cite>`                   | `is_italic_tag` → `italic = true`                  | `italic: true`      | `FontStyle.italic`                     | Supported |
| `<dfn>`                    | `is_italic_tag` → `italic = true`                  | `italic: true`      | `FontStyle.italic`                     | Supported |
| `<u>`                      | `is_underline_tag` → `underline = true`            | `underline: true`   | `TextDecoration.underline`             | Supported |
| `<ins>`                    | `is_underline_tag` → `underline = true`            | `underline: true`   | `TextDecoration.underline`             | Supported |
| `<a>`                      | Block context: `is_underline_tag` → `underline = true`; Inline context (inside `<p>`): falls to `_ =>` in `walk_inline_children`, **no hardcoded underline** — only CSS `text-decoration` applies; href never captured | Block: `underline: true`; Inline: CSS-dependent | Underline inconsistent between contexts; href lost, not navigable | Partial   |
| `<del>` / `<s>`            | `is_strikethrough_tag` → `line_through = true`     | `lineThrough: true` | `TextDecoration.lineThrough`           | Supported |
| `<code>`                   | Block context: `bold = true`; Inline context: falls to `_ =>` catch-all, **no bold** | Block: `bold: true`; Inline: unstyled | Block gets `FontWeight.bold`; inline `<code>` renders as normal text (no monospace, no bold) | Partial   |
| `<sup>`                    | Parsed into `TextNode.superscript`                 | `superscript: true` | FontFeature `sups` applied             | Partial   |
| `<sub>`                    | Parsed into `TextNode.subscript`                   | `subscript: true`   | FontFeature `subs` applied             | Partial   |
| `<small>`                  | Handled as generic inline (no font size reduction) | —                   | Normal text, should be ~0.8em          | Missing   |
| `<mark>`                   | Parsed into inline `background_color` when available | `backgroundColor` | Inline text highlight background color | Partial   |
| `<abbr>`                   | Handled as generic inline                          | —                   | Normal text                            | Missing   |
| `<q>`                      | Not in parser                                      | —                   | Not rendered as inline quote           | Missing   |
| `<kbd>`                    | Not in parser                                      | —                   | Not rendered                           | Missing   |
| `<var>`                    | Not in parser                                      | —                   | Not rendered as italic                 | Missing   |
| `<samp>`                   | Not in parser                                      | —                   | Not rendered as monospace              | Missing   |
| `<ruby>` / `<rt>` / `<rp>` | Not in parser                                      | —                   | Ruby annotations not rendered (CJK)    | Missing   |
| `<wbr>`                    | Not in parser                                      | —                   | Word break opportunity ignored         | Missing   |
| `<time>`                   | Not in parser                                      | —                   | Rendered as plain text; datetime semantics lost | Missing   |
| `<bdi>`                    | Not in parser                                      | —                   | BiDi isolation not applied             | Missing   |
| `<bdo>`                    | Not in parser                                      | —                   | Direction override not applied         | Missing   |
| `<data>`                   | Not in parser                                      | —                   | Machine-readable value semantics lost  | Missing   |
| `<span>`                   | Flatten (keep children)                            | —                   | CSS styling applied via `inherit_ctx`  | Supported |


### 1.3 Media & Embedded Elements


| HTML Tag          | Rust Behavior                      | RenderNode | Flutter Rendering                             | Status    |
| ----------------- | ---------------------------------- | ---------- | --------------------------------------------- | --------- |
| `<img>`           | Resolve src → base64, extract dims | `Image`    | `paintImage` on canvas via decoded `ui.Image` | Supported |
| `<svg>`           | Not handled (fallback walk)        | —          | Not rendered (would need SVG decoder)         | Missing   |
| `<audio>`         | Discarded                          | —          | —                                             | Discarded |
| `<video>`         | Discarded                          | —          | —                                             | Discarded |
| `<source>`        | Discarded                          | —          | —                                             | Discarded |
| `<iframe>`        | Discarded                          | —          | —                                             | Discarded |
| `<object>`        | Discarded                          | —          | —                                             | Discarded |
| `<embed>`         | Discarded                          | —          | —                                             | Discarded |
| `<picture>`       | Not handled                        | —          | Not rendered                                  | Missing   |
| `<canvas>`        | Not handled                        | —          | Not rendered                                  | Missing   |
| `<math>` (MathML) | Not handled                        | —          | Not rendered                                  | Missing   |


### 1.4 Discarded Elements (Intentional)


| HTML Tag             | Reason                              |
| -------------------- | ----------------------------------- |
| `<script>`           | No JS execution                     |
| `<style>`            | Discarded in chapter HTML; only manifest stylesheets are parsed by `css.rs` |
| `<link>`             | External resources not needed       |
| `<meta>`             | Metadata handled at book level      |
| `<head>`             | Not content                         |
| `<form>` / `<input>` | Interactive elements not applicable |
| `<noscript>`         | No JS context                       |


---

## 2. CSS Properties

### 2.1 Typography


| CSS Property                | Rust Extracts | RenderNode Field        | Flutter Uses | Status                   |
| --------------------------- | ------------- | ----------------------- | ------------ | ------------------------ |
| `font-weight`               | Y             | `TextNode.bold`         | Y            | Supported                |
| `font-style`                | Y             | `TextNode.italic`       | Y            | Supported                |
| `font-size`                 | Y             | `TextNode.font_size_em` | Y            | Supported                |
| `font-family`               | N             | —                       | —            | Missing (user pref only) |
| `font-variant` (small-caps) | N             | —                       | —            | Missing                  |
| `font-feature-settings`     | N             | —                       | —            | Missing                  |
| `letter-spacing`            | N             | —                       | —            | Missing                  |
| `word-spacing`              | N             | —                       | —            | Missing                  |
| `text-transform`            | N             | —                       | —            | Missing                  |


### 2.2 Text Decoration & Alignment


| CSS Property                               | Rust Extracts | RenderNode Field                      | Flutter Uses | Status                                       |
| ------------------------------------------ | ------------- | ------------------------------------- | ------------ | -------------------------------------------- |
| `text-decoration` / `text-decoration-line` | Y             | `TextNode.underline` / `line_through` | Y            | Supported                                    |
| `text-decoration-color`                    | N             | —                                     | —            | Missing                                      |
| `text-decoration-style`                    | N             | —                                     | —            | Missing                                      |
| `text-align`                               | Y             | `Paragraph.align` / `Heading.align`   | Partial      | Partial (`justify` currently maps to left)   |
| `text-indent`                              | Y             | `Paragraph.text_indent_em`            | Partial      | Parsed but currently normalized to no indent in Flutter layout |
| `text-shadow`                              | N             | —                                     | —            | Missing                                      |


### 2.3 Color & Background


| CSS Property       | Rust Extracts | RenderNode Field                                            | Flutter Uses | Status    |
| ------------------ | ------------- | ----------------------------------------------------------- | ------------ | --------- |
| `color`            | Y             | `TextNode.color` / `Heading.color` / `Paragraph.color` | Y | Supported |
| `background-color` | Y             | `Paragraph.background_color` / `TableCell.background_color` | Y            | Supported |
| `opacity`          | N             | —                                                           | —            | Missing   |


### 2.4 Box Model


| CSS Property                    | Rust Extracts     | RenderNode Field                  | Flutter Uses         | Status                            |
| ------------------------------- | ----------------- | --------------------------------- | -------------------- | --------------------------------- |
| `margin` (shorthand)            | Y                 | `margin_top/bottom/left/right_em` | Y                    | Supported                         |
| `margin-top`                    | Y                 | `margin_top_em`                   | Y                    | Supported                         |
| `margin-bottom`                 | Y                 | `margin_bottom_em`                | Y                    | Supported                         |
| `margin-left`                   | Y                 | `margin_left_em`                  | Y                    | Supported                         |
| `margin-right`                  | Y                 | `margin_right_em`                 | Y                    | Supported                         |
| `padding`                       | Y                 | `padding_em` (uniform only)       | Y                    | Supported                         |
| `padding-top/right/bottom/left` | Y (→ uniform)     | `padding_em`                      | Y                    | Partial (no per-side)             |
| `border`                        | Y                 | `TableCell.border`                | Y (table cells only) | Partial                           |
| `border-top`                    | Y                 | `border_top`                      | N                    | Missing (extracted, not rendered) |
| `border-bottom`                 | Y                 | `border_bottom`                   | N                    | Missing (extracted, not rendered) |
| `border-left` / `border-right`  | N                 | —                                 | —                    | Missing                           |
| `border-radius`                 | N                 | —                                 | —                    | Missing                           |
| `box-shadow`                    | N                 | —                                 | —                    | Missing                           |
| `width` / `height`              | N (img attr only) | —                                 | —                    | Missing                           |
| `max-width` / `min-width`       | N                 | —                                 | —                    | Missing                           |


### 2.5 Layout & Display


| CSS Property                  | Rust Extracts | RenderNode Field | Flutter Uses | Status                                 |
| ----------------------------- | ------------- | ---------------- | ------------ | -------------------------------------- |
| `display` (none/block/inline) | N             | —                | —            | **Missing (P0: hidden elements leak)** |
| `visibility`                  | N             | —                | —            | Missing                                |
| `float`                       | N             | —                | —            | Missing                                |
| `clear`                       | N             | —                | —            | Missing                                |
| `position`                    | N             | —                | —            | Missing                                |
| `z-index`                     | N             | —                | —            | Missing                                |
| `overflow`                    | N             | —                | —            | Missing                                |
| `flex-`*                      | N             | —                | —            | Missing                                |
| `grid-*`                      | N             | —                | —            | Missing                                |


### 2.6 Line & Spacing


| CSS Property     | Rust Extracts | RenderNode Field           | Flutter Uses | Status                            |
| ---------------- | ------------- | -------------------------- | ------------ | --------------------------------- |
| `line-height`    | Y             | `Paragraph.line_height_em` | Y            | Supported                         |
| `vertical-align` | Y             | `TableCell.vertical_align` | N            | Partial (extracted, not rendered) |
| `white-space`    | N             | —                          | —            | Missing                           |


### 2.7 List


| CSS Property          | Rust Extracts | RenderNode Field  | Flutter Uses                                | Status  |
| --------------------- | ------------- | ----------------- | ------------------------------------------- | ------- |
| `list-style-type`     | Y             | `List.list_style` | Partial (stored, Flutter uses fixed prefix) | Partial |
| `list-style-position` | N             | —                 | —                                           | Missing |
| `list-style-image`    | N             | —                 | —                                           | Missing |


### 2.8 Table


| HTML Attribute    | Rust Extracts | RenderNode Field | Flutter Uses | Status  |
| ----------------- | ------------- | ---------------- | ------------ | ------- |
| `colspan`         | N             | —                | —            | Missing |
| `rowspan`         | N             | —                | —            | Missing |
| `border-collapse` | N             | —                | —            | Missing |


### 2.9 Text Direction


| CSS Property          | Rust Extracts | RenderNode Field | Flutter Uses | Status  |
| --------------------- | ------------- | ---------------- | ------------ | ------- |
| `direction` (ltr/rtl) | N             | —                | —            | Missing |
| `writing-mode`        | N             | —                | —            | Missing |
| `unicode-bidi`        | N             | —                | —            | Missing |


---

## 3. Inline Text Styles Detail


| Visual Effect            | Triggering Tags                  | Rust → TextNode Field | Flutter TextStyle                        | Status    |
| ------------------------ | -------------------------------- | --------------------- | ---------------------------------------- | --------- |
| **Bold**                 | `<strong>`, `<b>`                | `bold: true`          | `fontWeight: FontWeight.bold`            | Supported |
| **Italic**               | `<em>`, `<i>`, `<cite>`, `<dfn>` | `italic: true`        | `fontStyle: FontStyle.italic`            | Supported |
| **Underline**            | `<u>`, `<ins>` (always); `<a>` (block context only — inline `<a>` inside `<p>` relies on CSS) | `underline: true`     | `decoration: TextDecoration.underline`   | Partial |
| **Strikethrough**        | `<del>`, `<s>`                   | `line_through: true`  | `decoration: TextDecoration.lineThrough` | Supported |
| **Font size**            | CSS `font-size`                  | `font_size_em`        | `fontSize: prefs.emToPx(em)`             | Supported |
| **Color**                | CSS `color`                      | `color: 0xAARRGGBB`   | `color: Color(node.color)`               | Supported |
| **Superscript**          | `<sup>`                          | `superscript: true`   | `FontFeature('sups')`                    | Partial   |
| **Subscript**            | `<sub>`                          | `subscript: true`     | `FontFeature('subs')`                    | Partial   |
| **Small text**           | `<small>`                        | — (no size reduction) | —                                        | Missing   |
| **Highlight**            | `<mark>`                         | `backgroundColor`     | `TextStyle.backgroundColor`              | Partial   |
| **Small caps**           | CSS `font-variant`               | —                     | —                                        | Missing   |
| **All caps / lowercase** | CSS `text-transform`             | —                     | —                                        | Missing   |
| **Letter spacing**       | CSS `letter-spacing`             | —                     | —                                        | Missing   |


---

## 4. Image Pipeline


| Feature                | Rust                                             | Flutter                                      | Status    |
| ---------------------- | ------------------------------------------------ | -------------------------------------------- | --------- |
| Base64 embedded images | Resolve `src` → `image_map` → base64             | `decodeImages()` → `ui.Image` → `paintImage` | Supported |
| Width hint (% attr)    | Parse `width="50%"` → `width_hint: 0.5`          | Scale to `contentWidth * widthHint`          | Supported |
| Native dimensions      | Read from image header → `width_px`, `height_px` | Used for aspect ratio                        | Supported |
| Alt text fallback      | `alt` attribute preserved                        | Italic placeholder `[alt text]`              | Supported |
| HiDPI / Retina         | —                                                | `targetWidth = maxWidth * devicePixelRatio`  | Supported |
| Max height cap         | —                                                | Cap to 80% of page height                    | Supported |
| Center alignment       | —                                                | `x = (contentWidth - displayW) / 2`          | Supported |
| SVG images             | Decode fails (not bitmap)                        | Falls back to alt text placeholder           | Missing   |
| Float (text wrap)      | Not extracted                                    | Always block-level, centered                 | Missing   |
| `<picture>` / `srcset` | Not handled                                      | —                                            | Missing   |


---

## 5. Missing Elements Summary

### P0 — Blocks Core Reading Experience (affects most books)


| Item | User-Visible Problem | Category | Fix Location |
|------|---------------------|----------|-------------|
| `display: none` | Hidden elements (duplicate titles, hidden nav) appear as visible text, cluttering pages | CSS | Rust `css.rs`: extract `display`; `html.rs`: skip nodes with `display: none` |
| Named CSS colors | `color: black`, `color: gray` etc. silently fail → text may use wrong color or fall back to default | CSS | Rust `css.rs` `parse_color()`: add named color map (CSS Level 1: 17 colors minimum) |
| Inline `style` attributes | `<p style="text-align: center">` ignored → one-off formatting lost (very common in EPUBs) | CSS | Rust `html.rs`: read `style` attr, parse with `parse_declarations()`, merge into resolved styles |
| Paragraph split background lost | Paragraphs with background color (code blocks, blockquotes) lose background at page breaks | Rendering | Flutter `paragraph_layouter.dart`: add `bgPaint` element in `_splitParagraph` for both parts |
| Paragraph split style loss | Bold/italic broken when paragraph crosses page boundary; `_truncateTextSpan` / `_skipTextSpan` don't recurse nested `TextSpan` | Rendering | Flutter `paragraph_layouter.dart`: recursive span truncation/skip |
| `text-indent` normalization | Reader intentionally disables mixed first-line indents to keep paragraphs visually aligned | Rendering | Flutter `paragraph_layouter.dart`: optional future toggle for original indent behavior |
| Nested lists broken | Nested `<ul>`/`<ol>` inside `<li>` flattened to inline text; list structure destroyed | HTML | Rust `html.rs`: detect nested lists in `<li>` and recurse with `collect_list_items` |
| Internal links not navigable | `<a href="#footnote1">` — href never captured; footnotes, TOC links, cross-refs all non-functional | HTML | Rust: preserve `href`; Flutter: handle tap on link regions |


### P1 — Common in Real Books, Noticeable Impact


| Item | User-Visible Problem | Category | Fix Location |
|------|---------------------|----------|-------------|
| Footnotes/endnotes | `epub:type="noteref"` / `epub:type="footnote"` not parsed; footnote popup/navigation impossible | EPUB | Rust `html.rs`: read `epub:type` attr, use for semantic rendering hints |
| Page break markers | `epub:type="pagebreak"` ignored; physical page numbers from print edition lost | EPUB | Rust `html.rs`: parse `epub:type="pagebreak"` and `id` for page number mapping |
| `<sup>` / `<sub>` | Footnote markers `[1]` render as normal-sized text instead of raised small text | HTML | Rust: set `font_size_em = 0.7` + add superscript/subscript field; Flutter: baseline offset |
| `<small>` tag | Copyright/legal text same size as body text | HTML | Rust `html.rs`: set `font_size_em = 0.8` for `<small>` tag |
| `<mark>` highlight | Author highlights invisible — no yellow background | HTML | Rust: propagate inline `background_color`; Flutter: paint background rect behind text span |
| `<li>` block children | `<li>` containing `<p>`, `<div>`, `<blockquote>` loses block structure | HTML | Rust `html.rs`: use `walk_children_of_node` for `<li>` or detect block children |
| Inline `<code>` styling | `<code>` inside paragraphs renders as plain text (no bold, no monospace) | HTML | Rust `html.rs` `walk_inline_children`: add `"code"` arm with `sub.bold = true` |
| `<pre>` child styling lost | Syntax-highlighted `<pre><code><span>` becomes plain text | HTML | Rust `html.rs`: walk inline children of `<pre>` to preserve `<span>` coloring |
| Figure/figcaption | `<figure>` and `<figcaption>` flattened; image captions lose semantic styling | HTML | Rust `html.rs`: add dedicated handling with container semantics |
| Table caption edge cases | Caption rendering depends on `Table.caption` presence in exported JSON; legacy cache may still miss caption | Data/cache | Re-export chapters for old cache files if caption is absent |
| `<a>` underline inconsistent | Block `<a>` gets underline; inline `<a>` (inside `<p>`) does not unless CSS provides it | HTML | Rust `html.rs` `walk_inline_children`: add explicit `"a"` arm with `underline = true` |
| List style rendering | Rust extracts 9 list-style variants but Flutter hardcodes "• " and "1. " only | Rendering | Flutter `_layoutList`: use `ListStyle` to select prefix |
| Heading color cascade limits | Heading-level color now applied, but complex CSS cascade precedence still depends on Rust style resolution | CSS | Improve selector/cascade fidelity in Rust `css.rs` |
| Descendant CSS selectors | `blockquote p { ... }`, `table td { ... }` stored but never matched | CSS | Rust `css.rs` `resolve_styles()`: match whitespace-separated ancestor chain |
| ID CSS selectors | `#chapter-title { font-size: 2em }` stored but never looked up | CSS | Rust `html.rs`: read `id` attr; `css.rs` `resolve_styles()`: check `#id` key |
| `!important` breaks parsing | `color: red !important` → value includes `" !important"` → `parse_color` fails | CSS | Rust `css.rs`: strip `!important` suffix before parsing values |
| `font` shorthand | `font: italic 700 1em/1.6 serif` completely ignored | CSS | Rust `css.rs`: add `font` shorthand expansion |
| `background` shorthand | `background: #f5f5f5` ignored unless explicit `background-color` is used | CSS | Rust `css.rs`: parse `background` shorthand color layer |
| `@font-face` | Custom EPUB fonts not loaded; always falls back to user-selected font | CSS | Rust: extract font files; Flutter: register fonts dynamically |
| `line-height: 120%` | Percentage line-heights fail to parse | CSS | Rust `css.rs` `parse_line_height()`: add `%` support |
| CSS global keywords | `inherit` / `initial` / `unset` / `revert` not interpreted | CSS | Rust `css.rs`: handle global keywords before field parsing |
| Extended color formats | `hsl()`, percentage `rgb()`, `transparent`, `currentColor` unsupported | CSS | Rust `css.rs` `parse_color()`: add additional color syntaxes |
| `list-style` token combos | `list-style: decimal inside` not parsed; only single tokens matched | CSS | Rust `css.rs`: tokenize `list-style` and extract type component |


### P2 — Affects Specific Content Types


| Item | User-Visible Problem | Category | Fix Location |
|------|---------------------|----------|-------------|
| Colspan/rowspan | Complex tables misaligned; merged cells don't span | HTML | Rust: read HTML attributes; Flutter: variable column layout |
| Definition lists `<dl>/<dt>/<dd>` | Glossaries/reference material loses term-definition structure | HTML | Rust `html.rs`: handle as List variant or styled Paragraphs |
| SVG images | Technical/scientific illustrations missing (alt text only) | HTML | Consider `flutter_svg` or pre-rasterize in Rust |
| RTL/BiDi text | Arabic, Hebrew, Persian text direction broken; `<bdi>`/`<bdo>` semantics ignored | HTML/CSS | Rust: parse `dir` attr + CSS `direction`; Flutter: `TextDirection.rtl` |
| Ruby annotations `<ruby>/<rt>` | CJK phonetic guides not rendered | HTML | Flutter: custom rendering for ruby annotations |
| Form controls (`<button>/<select>/<textarea>`) | Not discarded; may leak fallback text or empty artifacts | HTML | Rust `filter.rs`: add to discard list |
| `<fieldset>` / `<legend>` | Form-group content structure flattened | HTML | Rust `html.rs`: map to container node |
| `<meter>` / `<progress>` | Visual indicators dropped entirely | HTML | Rust `html.rs`: convert to fallback text |
| `<time>` / `<data>` semantics | Semantic metadata lost (plain text only) | HTML | Rust `html.rs`: preserve attributes if needed |
| Image pixel widths | `width="100px"` ignored; only `%` parsed | HTML | Rust `html.rs` `resolve_img()`: parse px and convert to ratio |
| URL-encoded image paths | `%20`, `%2F` not decoded before lookup | HTML | Rust `html.rs`: URL-decode `src` before resolving |
| `vertical-align` on table cells | Extracted but not applied; text always top-aligned | Rendering | Flutter `_layoutTable`: offset text within cell |
| `border-top` / `border-bottom` | Extracted by Rust but not rendered in Flutter | Rendering | Flutter `reader_canvas_painter.dart`: draw borders |
| `BorderNode.style` (dashed/dotted) | Border style extracted but never applied (always renders solid) | Rendering | Flutter `_layoutTable`: apply `strokeDashPattern` based on style |
| Node index tracking | Progress bookmarks can't track which paragraph user is at | Rendering | Flutter `layout_context.dart`: implement node index extraction |
| BlockQuote margin fields missing | CSS margins on `<blockquote>` silently discarded; hardcoded in Flutter | Rendering | Add margin fields to `BlockQuote` RenderNode (Rust + Dart) |
| Paragraph `color` field missing | Heading has `color` field but Paragraph does not; paragraph-level CSS color lost | Rendering | Add `color` field to `Paragraph` RenderNode (Rust + Dart) |
| `white-space: pre` | Whitespace collapsing mode not controllable | CSS | Rust: extract `white-space`; preserve raw whitespace |
| CSS specificity | No specificity ranking; stylesheet cascade unpredictable | CSS | Rust `css.rs`: implement basic specificity ordering |
| Extended color formats | `hsl()`, percentage `rgb()`, `transparent`, 4/8-digit hex not supported | CSS | Rust `css.rs` `parse_color()`: add formats |
| `rgb()` whitespace edge case | `rgb( 255, 128, 0 )` with spaces before `)` fails to parse | CSS | Rust `css.rs`: strip `)` before splitting on commas |
| Unit coverage (pt/cm/mm) | Print-origin EPUBs using `pt` silently fail; `rem` treated as `em` | CSS | Rust `css.rs` `parse_length_to_em()`: add unit conversions |


### P3 — Nice-to-Have Refinements


| Item | User-Visible Problem | Category | Fix Location |
|------|---------------------|----------|-------------|
| `font-variant: small-caps` | Typography lost | CSS | Flutter `TextStyle.fontFeatures` |
| `text-transform` | Case transforms ignored | CSS | Rust: apply transform to text content |
| `letter-spacing` / `word-spacing` | Typography refinements lost | CSS | Rust `css.rs` + Flutter `TextStyle` |
| `writing-mode: vertical-rl` | Vertical CJK text broken | CSS | Major layout engine change |
| `float` | Image text wrapping not possible | CSS | Major layout engine change |
| `<q>` | Inline quotes without quotation marks | HTML | Rust: wrap content in `"..."` |
| MathML `<math>` | Math formulas missing | HTML | Consider `flutter_math_fork` or pre-render |
| `::before` / `::after` | Generated content (quotes, counters) not rendered | CSS | Would require pseudo-element engine |
| `@media` queries | Print/screen-specific styles ignored | CSS | Rust: parse media queries, apply screen rules |
| `@import` | Nested stylesheets not followed | CSS | Rust: resolve and merge imported CSS |


---

## 7. CSS Engine Limitations

Systemic gaps in the Rust CSS parser (`css.rs`) and style resolution (`resolve_styles`) that affect many properties at once.

### 7.1 Inline `style` Attributes — NOT PARSED

`html.rs` never reads the `style="..."` attribute on HTML elements. `css.rs` is currently fed by manifest stylesheet resources, and chapter HTML `<style>` blocks are discarded with content tags. `resolve_styles()` takes `(tag, classes)` but never receives inline styles.

```html
<!-- This inline style is completely ignored -->
<p style="color: red; margin-top: 2em; text-align: center;">...</p>
```

**Impact**: HIGH — very common in EPUBs, especially for one-off formatting.

### 7.2 Named CSS Colors — NOT SUPPORTED

`parse_color()` in `css.rs:244-284` only handles:
- `#fff`, `#ffffff` (hex)
- `rgb(r, g, b)`, `rgba(r, g, b, a)`

Named colors return `None` (silently ignored):
```
black, white, red, green, blue, gray, grey, navy, teal, orange,
purple, maroon, silver, olive, lime, aqua, fuchsia, coral, gold, ...
```

**Impact**: MEDIUM-HIGH — many EPUBs use `color: black` or `color: gray`.

### 7.3 CSS Selector Coverage

`resolve_styles()` only matches 3 selector types. All others are stored in the CSS map but never looked up.

| Selector Type | Example | Supported |
|--------------|---------|:---------:|
| Tag | `p` | Y |
| Class | `.indent` | Y |
| Tag + Class | `p.indent` | Y |
| ID | `#chapter1` | N |
| Descendant | `blockquote p` | N |
| Child | `ul > li` | N |
| Multiple classes | `.bold.red` | N |
| Pseudo-class | `:first-child` | N |
| Pseudo-element | `::before`, `::after` | N |
| Attribute | `[epub\|type="footnote"]` | N |
| Universal | `*` | N |

**Impact**: HIGH — descendant selectors (`blockquote p`, `table td`) are standard in EPUB stylesheets.

### 7.4 CSS Specificity & Cascade — NOT IMPLEMENTED

- Rules stored in flat `HashMap<String, StyleProps>`; same selector overwrites previous
- No specificity calculation (ID > class > tag)
- No `!important` handling
- Cascade order depends on `HashMap` insertion (not guaranteed)
- Multiple CSS files loaded via `collect_all_css()` into a `HashMap<String, String>` keyed by href; `build_css_map()` iterates this in **nondeterministic order** and merges into a flat map — same selector from different CSS files overwrites unpredictably
- Chapter-specific `<style>` blocks embedded in XHTML content are **discarded** by `filter.rs` (`should_discard("style")`), so only manifest-level `.css` files are parsed; any chapter-specific overrides are lost

### 7.5 At-Rules — NOT PROCESSED

| At-Rule | Stored | Used | Impact |
|---------|:------:|:----:|--------|
| `@font-face` | Y (as selector key) | N | Custom EPUB fonts not loaded |
| `@import url(...)` | Y (as selector key) | N | Nested stylesheets not followed |
| `@media` | Y (as selector key) | N | Responsive/print overrides ignored |
| `@keyframes` | Y (as selector key) | N | Animations ignored (acceptable) |

### 7.6 Whitespace Handling

Text nodes are checked with `.trim().is_empty()` — if non-empty, the raw content (including leading/trailing whitespace, multiple spaces, newlines) is preserved as-is. No browser-style whitespace collapsing is applied. This differs from browser behavior where consecutive whitespace in inline context is collapsed to a single space.

### 7.7 Value Normalization & Shorthand Limitations

- `font` shorthand is not parsed, so compound typography declarations are lost unless the EPUB also provides longhands.
- `background` shorthand is not parsed, so color set via `background: ...` is dropped unless `background-color` is present.
- `list-style` shorthand only matches single-token values; combinations like `decimal inside` fail to set `list-style-type`.
- `line-height` only supports `normal`, unitless, `em`, and `px`; percentages like `120%` are ignored.
- Global CSS keywords (`inherit`, `initial`, `unset`, `revert`) are not interpreted, causing inconsistent fallback behavior.

**Impact**: HIGH — shorthand-heavy EPUB stylesheets lose large portions of intended typography and spacing.

### 7.8 Unit Support and `rem` Behavior

`parse_length_to_em()` currently supports `em`, `px`, `%`, keywords, and bare numbers. It does not support several units common in ebook CSS (`pt`, `cm`, `mm`, `in`, `vw`, `vh`). In addition, `rem` is currently treated as `em`, which is not semantically correct once nested relative scaling is involved.

**Impact**: MEDIUM-HIGH — books authored from print pipelines often rely on `pt`/physical units; root-relative sizing may drift.

### 7.9 Importance and Global Keyword Handling

- `!important` is not modeled in the cascade layer; declarations are parsed as raw strings and can break numeric/color parsing when the suffix remains attached.
- Even without parser failures, no cascade precedence exists to enforce important declarations over normal ones.
- Combined with missing global keyword handling, stylesheet intent cannot be resolved deterministically for many overrides.

**Impact**: HIGH — overrides intended by publishers may silently fail.

### 7.10 Color/Length Parser Edge Cases

Several edge cases in `css.rs` `parse_color()` and length parsing cause silent failures:

| Input | Parser Behavior | Root Cause |
|-------|----------------|------------|
| `rgb( 255, 128, 0 )` | Fails — last part becomes `"0 )"` → `u8::parse` fails | `)` not stripped before splitting on `,` |
| `#rgba` (4-digit hex) | Returns `None` | Only 3 and 6 digit hex branches exist |
| `#rrggbbaa` (8-digit hex) | Returns `None` | Only 3 and 6 digit hex branches exist |
| `rgb(100%, 50%, 0%)` | Fails — `"100%"` → `u8::parse` fails | Percentage RGB syntax not handled |
| `hsl(120, 100%, 50%)` | Returns `None` | HSL color function not implemented |
| `transparent` | Returns `None` | Named color / keyword not supported |
| `currentColor` | Returns `None` | Keyword not supported |
| `color: red !important` | Returns `None` — value is `"red !important"` | `!important` suffix not stripped before `parse_color` |

**Impact**: MEDIUM — individually rare, but in aggregate these failures affect a nontrivial fraction of EPUB stylesheets.

---

## 8. Flutter Renderer Bugs

Known implementation bugs in the Flutter layout/rendering pipeline.

### 8.1 Paragraph Split Loses Nested Styles

`paragraph_layouter.dart` — `_truncateTextSpan()` and `_skipTextSpan()` only iterate direct children of the root `TextSpan`. Nested hierarchies (e.g., bold wrapping italic) are not recursed into.

```
Input:  TextSpan(children: [TextSpan("Hello ", bold), TextSpan("world", bold+italic)])
Split at offset 4:

Expected Part 1: TextSpan(children: [TextSpan("Hell", bold)])
Actual Part 1:   TextSpan(children: [TextSpan("Hell", bold)])  ← OK

Expected Part 2: TextSpan(children: [TextSpan("o ", bold), TextSpan("world", bold+italic)])
Actual Part 2:   TextSpan(children: [TextSpan("o ", bold), TextSpan("world", bold+italic)])  ← OK for flat

But for deeply nested spans (TextSpan wrapping TextSpan wrapping TextSpan), children are lost.
```

**Impact**: Bold/italic/underline combinations may break when a paragraph crosses a page boundary.

### 8.2 `_extractPlainText()` Concatenation Order

`paragraph_layouter.dart:309-321` — the function puts `span.text` before `buffer` (child text) unconditionally:

```dart
if (span.text != null) {
  return span.text! + buffer.toString();  // Root text always first
}
```

This is usually fine since `TextSpanBuilder` produces spans without root text (only children), but could cause incorrect split offsets if a `TextSpan` has both `text` and `children`.

### 8.3 Node Index Tracking is a No-Op

`layout_context.dart` — the `_updateNodeIndexRange()` method is empty. `PageLayout.startNodeIndex` and `endNodeIndex` are always 0. This means fine-grained progress tracking (knowing which paragraph the user is at) doesn't work.

### 8.4 Split Paragraph Background Lost

`paragraph_layouter.dart:237-247` — `_splitParagraph` omits `backgroundPaint` for the first part when a paragraph with `backgroundColor` crosses a page boundary. Compare with `_placeParagraph` (lines 132-147) which correctly adds a background rect element.

```
Paragraph with backgroundColor at bottom of page:
┌──────────────────────────────┐
│  ██████████████████████████  │ ← _placeParagraph: bgPaint ✓
│  ██ Some styled block text █ │
│  ██████████████████████████  │
│─ ─ ─ page break ─ ─ ─ ─ ─ ─│
│  continuation text here      │ ← _splitParagraph: bgPaint ✗ (first part)
│                              │   second part also missing bg
└──────────────────────────────┘
```

**Impact**: Code blocks, blockquotes, and any paragraphs with background color lose their background at page breaks.

### 8.5 HeadingNode.color Silently Dropped

`reader_layout_engine.dart:140-151` — `_layoutHeading` creates a `ParagraphNode` proxy from the heading, but `ParagraphNode` has no `color` field (the Rust `Paragraph` variant also lacks it). The `HeadingNode.color` value is silently discarded.

```
HeadingNode(level: 1, color: 0xFF336699, children: [...])
    ↓ _layoutHeading()
ParagraphNode(children: [...], marginTopEm: 0.8, ...)  ← color field dropped
    ↓ ParagraphLayouter.layout()
TextSpan built from children only — heading-level color never applied
```

**Impact**: CSS `color` on headings (e.g., `h1 { color: navy }`) is extracted by Rust and transmitted over JSON but never applied during rendering.

---

## 9. EPUB-Specific Attributes

HTML attributes with special meaning in EPUB that are not captured by the parser.

| Attribute | Example | Parsed | Impact |
|-----------|---------|:------:|--------|
| `epub:type` | `<a epub:type="noteref" href="#fn1">1</a>` | N | Footnote/endnote markers not semantically identified |
| `epub:type="pagebreak"` | `<span epub:type="pagebreak" id="p42"/>` | N | Physical page numbers from print edition lost |
| `xml:lang` | `<p xml:lang="fr">Bonjour</p>` | N | Language-specific hyphenation/rendering not applied |
| `dir` | `<p dir="rtl">...` | N | RTL text direction not applied |
| `id` | `<div id="footnote1">` | N | Internal link targets (`href="#footnote1"`) can't resolve |
| `title` | `<abbr title="World Wide Web">WWW</abbr>` | N | Tooltip text lost |
| `colspan` | `<td colspan="2">` | N | Table cell spanning not rendered |
| `rowspan` | `<td rowspan="3">` | N | Table cell spanning not rendered |

---

## 10. Image Attribute Gaps

Additional image handling gaps beyond what's in Section 4.

| Attribute / Feature | Current Behavior | Expected |
|--------------------|--------------------|----------|
| `width="100px"` | Ignored (only `%` parsed) | Should convert px to ratio |
| `width="5cm"` | Ignored | Could convert to approximate px |
| `height` attribute | Not used at all | Could provide aspect ratio hint |
| URL-encoded paths (`%20`) | Not decoded before lookup | Should URL-decode before matching |
| `style="width: 50%"` | Ignored (inline styles not parsed) | Should parse inline width |
| `srcset` attribute | Not handled | Multi-resolution images not supported |

---

## 6. File Reference


| File                                                   | Role                                                          |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| `rust/epub_parser/src/model.rs`                        | `RenderNode` enum (Rust side)                                 |
| `rust/epub_parser/src/html.rs`                         | HTML tag → `RenderNode` conversion                            |
| `rust/epub_parser/src/css.rs`                          | CSS property extraction → `StyleProps`                        |
| `rust/epub_parser/src/filter.rs`                       | Tag discard/flatten/bold/italic/underline/strikethrough lists |
| `lib/services/reader/models/render_node.dart`          | `RenderNode` sealed class (Flutter side)                      |
| `lib/services/reader/models/page_layout.dart`          | `LayoutElement`, `PageLayout`, `ChapterPagination`            |
| `lib/services/reader/layout/reader_layout_engine.dart` | Pagination engine, image decoding, node dispatch              |
| `lib/services/reader/layout/paragraph_layouter.dart`   | Paragraph measurement, cross-page splitting                   |
| `lib/services/reader/layout/text_span_builder.dart`    | `RenderNode` children → `TextSpan` tree                       |
| `lib/services/reader/layout/layout_context.dart`       | Mutable layout state (cursor, pages, margins)                 |
| `lib/pages/reader/widgets/reader_canvas_painter.dart`  | `CustomPainter` rendering `PageLayout` to canvas              |
| `lib/stores/reader/reader_store.dart`                  | Reader state management, caching, navigation                  |
