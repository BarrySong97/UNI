use std::collections::HashMap;

use scraper::{ElementRef, Html, Node};

use crate::css::{self, StyleProps};
use crate::filter;
use crate::model::*;

/// Image data: (base64_string, Option<(width_px, height_px)>).
type ImageInfo = (String, Option<(u32, u32)>);

/// Context carried through the recursive walk.
struct WalkCtx<'a> {
    css_map: &'a HashMap<String, StyleProps>,
    image_map: &'a HashMap<String, ImageInfo>,
    /// Href of the current chapter (for resolving relative image paths).
    chapter_href: &'a str,
    char_offset: &'a mut usize,
    block_index: &'a mut usize,
    bold: bool,
    italic: bool,
    underline: bool,
    line_through: bool,
    font_size_em: f32,
    color: Option<u32>,
    background_color: Option<u32>,
    href: Option<String>,
    superscript: bool,
    subscript: bool,
    /// Ancestor tag stack for descendant CSS selector matching.
    ancestors: Vec<String>,
}

/// Parse an XHTML string into a flat list of block-level `RenderNode`s.
pub fn parse_xhtml(
    xhtml: &str,
    css_map: &HashMap<String, StyleProps>,
    image_map: &HashMap<String, ImageInfo>,
    chapter_href: &str,
    char_offset: &mut usize,
) -> Vec<RenderNode> {
    let document = Html::parse_document(xhtml);
    let mut block_index = 0usize;

    let mut ctx = WalkCtx {
        css_map,
        image_map,
        chapter_href,
        char_offset,
        block_index: &mut block_index,
        bold: false,
        italic: false,
        underline: false,
        line_through: false,
        font_size_em: 1.0,
        color: None,
        background_color: None,
        href: None,
        superscript: false,
        subscript: false,
        ancestors: Vec::new(),
    };

    let mut nodes = Vec::new();
    walk_children_of_node(document.root_element(), &mut ctx, &mut nodes);

    // Trim trailing empty nodes.
    while nodes.last().map_or(false, is_empty_node) {
        nodes.pop();
    }

    nodes
}

// ---------------------------------------------------------------------------
// Recursive DOM walker
// ---------------------------------------------------------------------------

fn walk_children_of_node(elem: ElementRef, ctx: &mut WalkCtx, out: &mut Vec<RenderNode>) {
    for child in elem.children() {
        match child.value() {
            Node::Text(text) => {
                let s = text.text.to_string();
                if !s.trim().is_empty() {
                    let node_index = *ctx.char_offset;
                    *ctx.char_offset += s.len();
                    out.push(RenderNode::Text {
                        content: s,
                        bold: ctx.bold,
                        italic: ctx.italic,
                        underline: ctx.underline,
                        line_through: ctx.line_through,
                        font_size_em: ctx.font_size_em,
                        color: ctx.color,
                        node_index,
                        href: ctx.href.clone(),
                        superscript: ctx.superscript,
                        subscript: ctx.subscript,
                        background_color: ctx.background_color,
                    });
                }
            }
            Node::Element(_) => {
                let child_elem = ElementRef::wrap(child).unwrap();
                walk_block_element(child_elem, ctx, out);
            }
            _ => {}
        }
    }
}

fn walk_block_element(elem: ElementRef, ctx: &mut WalkCtx, out: &mut Vec<RenderNode>) {
    let tag = elem.value().name.local.as_ref().to_lowercase();

    if filter::should_discard(&tag) {
        return;
    }

    if tag == "nav" && has_epub_type_token(elem, "landmarks") {
        return;
    }

    let style = resolve_styles_with_inline(ctx, elem, &tag);

    // Skip elements with display:none.
    if style.display.as_deref() == Some("none") {
        return;
    }

    // Skip elements positioned out of normal flow (position: absolute/fixed).
    // These are typically decorative images, logos, or watermarks.
    if filter::should_skip_out_of_flow(&tag, &style) {
        return;
    }

    if filter::should_flatten(&tag) {
        let mut sub = inherit_ctx(ctx, &style);
        sub.ancestors.push(tag.clone());
        walk_children_of_node(elem, &mut sub, out);
        *ctx.char_offset = *sub.char_offset;
        return;
    }

    match tag.as_str() {
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
            let level = filter::heading_level(&tag).unwrap_or(1);
            let children = collect_inline(elem, ctx, &style, &tag);
            if !children.is_empty() {
                out.push(RenderNode::Heading {
                    level,
                    children,
                    block_index: next_block_index(ctx),
                    margin_top_em: style.margin_top_em.unwrap_or(0.0),
                    margin_bottom_em: style.margin_bottom_em.unwrap_or(0.0),
                    margin_left_em: style.margin_left_em.unwrap_or(0.0),
                    margin_right_em: style.margin_right_em.unwrap_or(0.0),
                    align: style.text_align.unwrap_or(TextAlign::Left),
                    color: style.color,
                    text_indent_em: style.text_indent_em,
                    line_height_em: style.line_height_em,
                    padding_em: style.padding_em,
                    background_color: style.background_color,
                });
            }
        }

        "p" => {
            let children = collect_inline(elem, ctx, &style, &tag);
            if !children.is_empty() {
                out.push(RenderNode::Paragraph {
                    children,
                    block_index: next_block_index(ctx),
                    margin_top_em: style.margin_top_em.unwrap_or(0.0),
                    margin_bottom_em: style.margin_bottom_em.unwrap_or(0.5),
                    margin_left_em: style.margin_left_em.unwrap_or(0.0),
                    margin_right_em: style.margin_right_em.unwrap_or(0.0),
                    align: style.text_align.unwrap_or(TextAlign::Left),
                    text_indent_em: style.text_indent_em,
                    line_height_em: style.line_height_em,
                    padding_em: style.padding_em,
                    background_color: style.background_color,
                    color: style.color,
                });
            }
        }

        // --- Inline formatting tags at block level ---
        "strong" | "b" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.bold = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "em" | "i" | "cite" | "dfn" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.italic = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "u" | "ins" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.underline = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "del" | "s" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.line_through = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "a" => {
            let mut sub = inherit_ctx(ctx, &style);
            // Never set underline from <a> tags — the Flutter rendering
            // layer decides link styling based on href type (external vs
            // internal).  This also avoids the html5ever issue where
            // self-closing `<a id="page_N"/>` is parsed as a non-void
            // opening tag that swallows subsequent content.
            sub.href = elem.value().attr("href").map(|s| s.to_string());
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "sup" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.7;
            sub.superscript = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "sub" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.7;
            sub.subscript = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "small" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.8;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "mark" => {
            let mut sub = inherit_ctx(ctx, &style);
            if sub.background_color.is_none() {
                sub.background_color = Some(0xFFFFFF00);
            }
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "abbr" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }

        "br" => {
            out.push(RenderNode::LineBreak);
        }

        "hr" => {
            out.push(RenderNode::HorizontalRule);
        }

        "img" => {
            let alt = elem.value().attr("alt").map(|s| s.to_string());
            let img = resolve_img(elem, ctx, Some(&style));
            out.push(RenderNode::Image {
                data_base64: img.data_base64,
                alt,
                width_hint: img.width_hint,
                width_px: img.width_px,
                height_px: img.height_px,
            });
        }

        "figure" | "figcaption" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }

        "ol" | "ul" => {
            let ordered = tag == "ol";
            let items = collect_list_items(elem, ctx, &tag);
            if !items.is_empty() {
                out.push(RenderNode::List {
                    ordered,
                    items,
                    block_index: next_block_index(ctx),
                    list_style: style.list_style_type,
                });
            }
        }

        "li" => {
            let children = collect_inline(elem, ctx, &style, &tag);
            if !children.is_empty() {
                out.push(RenderNode::Paragraph {
                    children,
                    block_index: next_block_index(ctx),
                    margin_top_em: 0.0,
                    margin_bottom_em: 0.3,
                    margin_left_em: style.margin_left_em.unwrap_or(0.0),
                    margin_right_em: style.margin_right_em.unwrap_or(0.0),
                    align: TextAlign::Left,
                    text_indent_em: style.text_indent_em,
                    line_height_em: style.line_height_em,
                    padding_em: style.padding_em,
                    background_color: style.background_color,
                    color: style.color,
                });
            }
        }

        "table" => {
            let (rows, caption) = collect_table_rows(elem, ctx);
            if !rows.is_empty() {
                out.push(RenderNode::Table {
                    rows,
                    block_index: next_block_index(ctx),
                    caption,
                });
            }
        }

        "blockquote" => {
            let mut children = Vec::new();
            let mut sub = inherit_ctx(ctx, &style);
            sub.italic = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, &mut children);
            *ctx.char_offset = *sub.char_offset;
            if !children.is_empty() {
                out.push(RenderNode::BlockQuote {
                    children,
                    block_index: next_block_index(ctx),
                    background_color: style.background_color,
                    margin_top_em: style.margin_top_em.unwrap_or(0.5),
                    margin_bottom_em: style.margin_bottom_em.unwrap_or(0.5),
                    margin_left_em: style.margin_left_em.unwrap_or(2.0),
                    margin_right_em: style.margin_right_em.unwrap_or(1.0),
                });
            }
        }

        "pre" => {
            // Walk inline children to preserve <span>/<code> styling.
            let mut children = Vec::new();
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.85;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, &mut children);
            *ctx.char_offset = *sub.char_offset;
            if !children.is_empty() {
                out.push(RenderNode::CodeBlock {
                    children,
                    block_index: next_block_index(ctx),
                    background_color: style.background_color.or(Some(0xFFF5F5F5)),
                    padding_em: style.padding_em.or(Some(0.5)),
                });
            }
        }

        "code" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.bold = true;
            sub.ancestors.push(tag.clone());
            walk_children_of_node(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }

        "dl" => {
            // Definition list: <dt> → bold paragraph, <dd> → indented paragraph.
            ctx.ancestors.push(tag.clone());
            for dl_child in elem.children() {
                if let Some(dl_child_elem) = ElementRef::wrap(dl_child) {
                    let dt_tag = dl_child_elem.value().name.local.as_ref().to_lowercase();
                    let dl_style = resolve_styles_with_inline(ctx, dl_child_elem, &dt_tag);
                    match dt_tag.as_str() {
                        "dt" => {
                            let mut sub = inherit_ctx(ctx, &dl_style);
                            sub.bold = true;
                            let children =
                                collect_inline(dl_child_elem, &mut sub, &dl_style, &dt_tag);
                            *ctx.char_offset = *sub.char_offset;
                            if !children.is_empty() {
                                out.push(RenderNode::Paragraph {
                                    children,
                                    block_index: next_block_index(ctx),
                                    margin_top_em: dl_style.margin_top_em.unwrap_or(0.3),
                                    margin_bottom_em: dl_style.margin_bottom_em.unwrap_or(0.1),
                                    margin_left_em: dl_style.margin_left_em.unwrap_or(0.0),
                                    margin_right_em: dl_style.margin_right_em.unwrap_or(0.0),
                                    align: TextAlign::Left,
                                    text_indent_em: None,
                                    line_height_em: None,
                                    padding_em: None,
                                    background_color: None,
                                    color: dl_style.color,
                                });
                            }
                        }
                        "dd" => {
                            let children = collect_inline(dl_child_elem, ctx, &dl_style, &dt_tag);
                            if !children.is_empty() {
                                out.push(RenderNode::Paragraph {
                                    children,
                                    block_index: next_block_index(ctx),
                                    margin_top_em: dl_style.margin_top_em.unwrap_or(0.0),
                                    margin_bottom_em: dl_style.margin_bottom_em.unwrap_or(0.3),
                                    margin_left_em: dl_style.margin_left_em.unwrap_or(2.0),
                                    margin_right_em: dl_style.margin_right_em.unwrap_or(0.0),
                                    align: TextAlign::Left,
                                    text_indent_em: None,
                                    line_height_em: None,
                                    padding_em: None,
                                    background_color: None,
                                    color: dl_style.color,
                                });
                            }
                        }
                        _ => {
                            walk_children_of_node(dl_child_elem, ctx, out);
                        }
                    }
                }
            }
            ctx.ancestors.pop();
        }

        "thead" | "tbody" | "tfoot" | "tr" | "td" | "th" | "caption" | "colgroup" | "col" => {
            walk_children_of_node(elem, ctx, out);
        }

        _ => {
            walk_children_of_node(elem, ctx, out);
        }
    }
}

// ---------------------------------------------------------------------------
// Inline content collection
// ---------------------------------------------------------------------------

fn collect_inline(
    elem: ElementRef,
    ctx: &mut WalkCtx,
    parent_style: &StyleProps,
    parent_tag: &str,
) -> Vec<RenderNode> {
    let mut nodes = Vec::new();
    let mut sub = inherit_ctx(ctx, parent_style);
    sub.ancestors.push(parent_tag.to_string());
    walk_inline_children(elem, &mut sub, &mut nodes);
    *ctx.char_offset = *sub.char_offset;
    nodes
}

fn walk_inline_children(elem: ElementRef, ctx: &mut WalkCtx, out: &mut Vec<RenderNode>) {
    for child in elem.children() {
        match child.value() {
            Node::Text(text) => {
                let s = text.text.to_string();
                if !s.trim().is_empty() {
                    let node_index = *ctx.char_offset;
                    *ctx.char_offset += s.len();
                    out.push(RenderNode::Text {
                        content: s,
                        bold: ctx.bold,
                        italic: ctx.italic,
                        underline: ctx.underline,
                        line_through: ctx.line_through,
                        font_size_em: ctx.font_size_em,
                        color: ctx.color,
                        node_index,
                        href: ctx.href.clone(),
                        superscript: ctx.superscript,
                        subscript: ctx.subscript,
                        background_color: ctx.background_color,
                    });
                }
            }
            Node::Element(_) => {
                let child_elem = ElementRef::wrap(child).unwrap();
                walk_inline_element(child_elem, ctx, out);
            }
            _ => {}
        }
    }
}

fn walk_inline_element(elem: ElementRef, ctx: &mut WalkCtx, out: &mut Vec<RenderNode>) {
    let tag = elem.value().name.local.as_ref().to_lowercase();
    if filter::should_discard(&tag) {
        return;
    }

    let style = resolve_styles_with_inline(ctx, elem, &tag);

    // Skip elements with display:none.
    if style.display.as_deref() == Some("none") {
        return;
    }

    // Skip positioned-out-of-flow elements in inline context too.
    if filter::should_skip_out_of_flow(&tag, &style) {
        return;
    }

    match tag.as_str() {
        "br" => out.push(RenderNode::LineBreak),
        "img" => {
            let alt = elem.value().attr("alt").map(|s| s.to_string());
            let img = resolve_img(elem, ctx, Some(&style));
            out.push(RenderNode::Image {
                data_base64: img.data_base64,
                alt,
                width_hint: img.width_hint,
                width_px: img.width_px,
                height_px: img.height_px,
            });
        }
        "strong" | "b" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.bold = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "em" | "i" | "cite" | "dfn" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.italic = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "u" | "ins" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.underline = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "del" | "s" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.line_through = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "a" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.href = elem.value().attr("href").map(|s| s.to_string());
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "sup" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.7;
            sub.superscript = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "sub" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.7;
            sub.subscript = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "small" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.font_size_em *= 0.8;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "mark" => {
            let mut sub = inherit_ctx(ctx, &style);
            if sub.background_color.is_none() {
                sub.background_color = Some(0xFFFFFF00);
            }
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        "code" => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.bold = true;
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
        _ => {
            let mut sub = inherit_ctx(ctx, &style);
            sub.ancestors.push(tag.clone());
            walk_inline_children(elem, &mut sub, out);
            *ctx.char_offset = *sub.char_offset;
        }
    }
}

fn has_epub_type_token(elem: ElementRef, needle: &str) -> bool {
    elem.value()
        .attr("epub:type")
        .map(|value| {
            value
                .split_whitespace()
                .any(|token| token.eq_ignore_ascii_case(needle))
        })
        .unwrap_or(false)
}

// ---------------------------------------------------------------------------
// List items
// ---------------------------------------------------------------------------

/// Block-level tags that signal a <li> has block children (not just inline text).
fn is_block_tag(tag: &str) -> bool {
    matches!(
        tag,
        "p" | "div"
            | "ul"
            | "ol"
            | "blockquote"
            | "pre"
            | "table"
            | "h1"
            | "h2"
            | "h3"
            | "h4"
            | "h5"
            | "h6"
            | "dl"
    )
}

fn collect_list_items(elem: ElementRef, ctx: &mut WalkCtx, list_tag: &str) -> Vec<ListItem> {
    let mut items = Vec::new();
    ctx.ancestors.push(list_tag.to_string());

    for child in elem.children() {
        if let Some(child_elem) = ElementRef::wrap(child) {
            let tag = child_elem.value().name.local.as_ref().to_lowercase();
            if tag == "li" {
                let style = resolve_styles_with_inline(ctx, child_elem, &tag);

                // Check if <li> contains any block-level children.
                let has_block_children = child_elem.children().any(|c| {
                    ElementRef::wrap(c).map_or(false, |e| {
                        is_block_tag(&e.value().name.local.as_ref().to_lowercase())
                    })
                });

                if has_block_children {
                    let mut inline_children = Vec::new();
                    let mut sub_nodes = Vec::new();
                    let mut sub = inherit_ctx(ctx, &style);
                    sub.ancestors.push("li".to_string());

                    for li_child in child_elem.children() {
                        match li_child.value() {
                            Node::Text(text) => {
                                let s = text.text.to_string();
                                if !s.trim().is_empty() {
                                    let node_index = *sub.char_offset;
                                    *sub.char_offset += s.len();
                                    inline_children.push(RenderNode::Text {
                                        content: s,
                                        bold: sub.bold,
                                        italic: sub.italic,
                                        underline: sub.underline,
                                        line_through: sub.line_through,
                                        font_size_em: sub.font_size_em,
                                        color: sub.color,
                                        node_index,
                                        href: sub.href.clone(),
                                        superscript: sub.superscript,
                                        subscript: sub.subscript,
                                        background_color: sub.background_color,
                                    });
                                }
                            }
                            Node::Element(_) => {
                                if let Some(li_child_elem) = ElementRef::wrap(li_child) {
                                    let t =
                                        li_child_elem.value().name.local.as_ref().to_lowercase();
                                    if is_block_tag(&t) {
                                        // Block child → preserve the wrapper node itself.
                                        walk_block_element(li_child_elem, &mut sub, &mut sub_nodes);
                                    } else {
                                        // Inline child → preserve element formatting like <a>.
                                        walk_inline_element(
                                            li_child_elem,
                                            &mut sub,
                                            &mut inline_children,
                                        );
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                    *ctx.char_offset = *sub.char_offset;
                    items.push(ListItem {
                        children: inline_children,
                        sub_nodes,
                    });
                } else {
                    let children = collect_inline(child_elem, ctx, &style, &tag);
                    items.push(ListItem {
                        children,
                        sub_nodes: Vec::new(),
                    });
                }
            }
        }
    }

    ctx.ancestors.pop();
    items
}

// ---------------------------------------------------------------------------
// Table rows
// ---------------------------------------------------------------------------

fn collect_table_rows(
    elem: ElementRef,
    ctx: &mut WalkCtx,
) -> (Vec<TableRow>, Option<Vec<RenderNode>>) {
    let mut rows = Vec::new();
    let mut caption = None;
    ctx.ancestors.push("table".to_string());
    collect_table_rows_recursive(elem, ctx, &mut rows, &mut caption);
    ctx.ancestors.pop();
    (rows, caption)
}

fn collect_table_rows_recursive(
    elem: ElementRef,
    ctx: &mut WalkCtx,
    rows: &mut Vec<TableRow>,
    caption: &mut Option<Vec<RenderNode>>,
) {
    for child in elem.children() {
        if let Some(child_elem) = ElementRef::wrap(child) {
            let tag = child_elem.value().name.local.as_ref().to_lowercase();
            match tag.as_str() {
                "tr" => {
                    let (cells, is_header) = collect_table_cells(child_elem, ctx);
                    rows.push(TableRow { cells, is_header });
                }
                "thead" | "tbody" | "tfoot" => {
                    collect_table_rows_recursive(child_elem, ctx, rows, caption);
                }
                "caption" => {
                    let style = resolve_styles_with_inline(ctx, child_elem, &tag);
                    let children = collect_inline(child_elem, ctx, &style, &tag);
                    if !children.is_empty() {
                        *caption = Some(children);
                    }
                }
                _ => {}
            }
        }
    }
}

fn collect_table_cells(elem: ElementRef, ctx: &mut WalkCtx) -> (Vec<TableCell>, bool) {
    let mut cells = Vec::new();
    let mut is_header = false;
    for child in elem.children() {
        if let Some(child_elem) = ElementRef::wrap(child) {
            let tag = child_elem.value().name.local.as_ref().to_lowercase();
            if tag == "td" || tag == "th" {
                if tag == "th" {
                    is_header = true;
                }
                let style = resolve_styles_with_inline(ctx, child_elem, &tag);
                let mut children = Vec::new();
                let mut sub = inherit_ctx(ctx, &style);
                sub.ancestors.push(tag.clone());
                walk_children_of_node(child_elem, &mut sub, &mut children);
                *ctx.char_offset = *sub.char_offset;

                // Read colspan/rowspan HTML attributes.
                let colspan = child_elem
                    .value()
                    .attr("colspan")
                    .and_then(|v| v.parse::<u32>().ok())
                    .filter(|&v| v > 1);
                let rowspan = child_elem
                    .value()
                    .attr("rowspan")
                    .and_then(|v| v.parse::<u32>().ok())
                    .filter(|&v| v > 1);

                cells.push(TableCell {
                    children,
                    background_color: style.background_color,
                    padding_em: style.padding_em,
                    border: style.border,
                    vertical_align: style.vertical_align,
                    colspan,
                    rowspan,
                });
            }
        }
    }
    (cells, is_header)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Resolve CSS styles for an element, merging stylesheet rules with inline `style` attribute.
fn resolve_styles_with_inline(ctx: &WalkCtx, elem: ElementRef, tag: &str) -> StyleProps {
    let classes = element_classes(elem);
    let id = elem.value().attr("id");
    let mut style = css::resolve_styles(ctx.css_map, tag, &classes, id, &ctx.ancestors);
    if let Some(inline) = elem.value().attr("style") {
        let inline_props = css::parse_declarations(inline);
        css::merge_props(&mut style, &inline_props);
    }
    style
}

fn inherit_ctx<'a>(parent: &'a mut WalkCtx, style: &StyleProps) -> WalkCtx<'a> {
    WalkCtx {
        css_map: parent.css_map,
        image_map: parent.image_map,
        chapter_href: parent.chapter_href,
        char_offset: parent.char_offset,
        block_index: parent.block_index,
        bold: style.bold.unwrap_or(parent.bold),
        italic: style.italic.unwrap_or(parent.italic),
        underline: style.underline.unwrap_or(parent.underline),
        line_through: style.line_through.unwrap_or(parent.line_through),
        font_size_em: style.font_size_em.unwrap_or(parent.font_size_em),
        color: style.color.or(parent.color),
        background_color: style.background_color.or(parent.background_color),
        href: parent.href.clone(),
        superscript: parent.superscript,
        subscript: parent.subscript,
        ancestors: parent.ancestors.clone(),
    }
}

fn next_block_index(ctx: &mut WalkCtx) -> usize {
    let next = *ctx.block_index;
    *ctx.block_index += 1;
    next
}

/// Resolved image info: base64, width_hint, width_px, height_px.
struct ResolvedImage {
    data_base64: Option<String>,
    width_hint: Option<f32>,
    width_px: Option<u32>,
    height_px: Option<u32>,
}

/// URL-decode a percent-encoded string (e.g. %20 → space).
fn url_decode(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let bytes = s.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hi = (bytes[i + 1] as char).to_digit(16);
            let lo = (bytes[i + 2] as char).to_digit(16);
            if let (Some(h), Some(l)) = (hi, lo) {
                result.push(((h * 16 + l) as u8) as char);
                i += 3;
                continue;
            }
        }
        result.push(bytes[i] as char);
        i += 1;
    }
    result
}

/// Resolve an `<img>` element's `src` to base64 data, dimensions, and optional width hint.
fn resolve_img(elem: ElementRef, ctx: &WalkCtx, style: Option<&StyleProps>) -> ResolvedImage {
    let src = match elem.value().attr("src") {
        Some(s) => s,
        None => {
            return ResolvedImage {
                data_base64: None,
                width_hint: None,
                width_px: None,
                height_px: None,
            }
        }
    };

    // URL-decode the src before resolving.
    let src_decoded = url_decode(src);

    // Resolve relative src against the chapter's directory.
    let chapter_dir = ctx
        .chapter_href
        .rsplit_once('/')
        .map(|(d, _)| d)
        .unwrap_or("");
    let resolved = normalize_path(&format!("{}/{}", chapter_dir, &src_decoded));

    // Try resolved path first, then raw src, then decoded src, then just the filename.
    let filename = src_decoded.rsplit('/').next().unwrap_or(&src_decoded);
    let info = ctx
        .image_map
        .get(&resolved)
        .or_else(|| ctx.image_map.get(src))
        .or_else(|| ctx.image_map.get(&src_decoded))
        .or_else(|| ctx.image_map.get(filename));

    let (data_base64, dims) = match info {
        Some((b64, dims)) => (Some(b64.clone()), *dims),
        None => (None, None),
    };

    // Parse width attribute for width_hint.
    let width_hint = elem.value().attr("width").and_then(|w| {
        if w.ends_with('%') {
            w.trim_end_matches('%')
                .parse::<f32>()
                .ok()
                .map(|v| v / 100.0)
        } else if w.ends_with("px") {
            // Explicit pixel width with unit — use heuristic ratio.
            w.trim_end_matches("px")
                .parse::<f32>()
                .ok()
                .map(|px| (px / 600.0).min(1.0))
        } else {
            // Bare number (e.g. width="200") — treat as pixels.
            w.parse::<f32>().ok().map(|px| (px / 600.0).min(1.0))
        }
    });

    // Fallback: use CSS width property when HTML attribute is absent.
    let width_hint = width_hint.or_else(|| {
        style.and_then(|s| s.width.as_deref()).and_then(|w| {
            if w == "auto" || w == "0" {
                return None;
            }
            if w.ends_with('%') {
                w.trim_end_matches('%')
                    .parse::<f32>()
                    .ok()
                    .map(|v| v / 100.0)
            } else if w.ends_with("px") {
                w.trim_end_matches("px")
                    .parse::<f32>()
                    .ok()
                    .map(|px| (px / 600.0).min(1.0))
            } else {
                w.parse::<f32>().ok().map(|px| (px / 600.0).min(1.0))
            }
        })
    });

    ResolvedImage {
        data_base64,
        width_hint,
        width_px: dims.map(|(w, _)| w),
        height_px: dims.map(|(_, h)| h),
    }
}

/// Normalize a path by resolving `..` and `.` segments.
fn normalize_path(path: &str) -> String {
    let mut parts: Vec<&str> = Vec::new();
    for segment in path.split('/') {
        match segment {
            "" | "." => {}
            ".." => {
                parts.pop();
            }
            s => parts.push(s),
        }
    }
    parts.join("/")
}

fn element_classes(elem: ElementRef) -> Vec<String> {
    elem.value()
        .attr("class")
        .map(|c| c.split_whitespace().map(|s| s.to_lowercase()).collect())
        .unwrap_or_default()
}

fn is_empty_node(node: &RenderNode) -> bool {
    match node {
        RenderNode::Paragraph { children, .. } => children.is_empty(),
        RenderNode::Heading { children, .. } => children.is_empty(),
        _ => false,
    }
}
