use std::collections::HashMap;

use scraper::{Html, Node, ElementRef};

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
    bold: bool,
    italic: bool,
    underline: bool,
    line_through: bool,
    font_size_em: f32,
    color: Option<u32>,
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

    let mut ctx = WalkCtx {
        css_map,
        image_map,
        chapter_href,
        char_offset,
        bold: false,
        italic: false,
        underline: false,
        line_through: false,
        font_size_em: 1.0,
        color: None,
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
                    });
                }
            }
            Node::Element(el) => {
                let tag = el.name.local.as_ref().to_lowercase();

                if filter::should_discard(&tag) {
                    continue;
                }

                let child_elem = ElementRef::wrap(child).unwrap();
                let classes = element_classes(child_elem);
                let style = css::resolve_styles(ctx.css_map, &tag, &classes);

                if filter::should_flatten(&tag) {
                    let mut sub = inherit_ctx(ctx, &style);
                    walk_children_of_node(child_elem, &mut sub, out);
                    *ctx.char_offset = *sub.char_offset;
                    continue;
                }

                match tag.as_str() {
                    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
                        let level = filter::heading_level(&tag).unwrap_or(1);
                        let children = collect_inline(child_elem, ctx, &style);
                        if !children.is_empty() {
                            out.push(RenderNode::Heading {
                                level,
                                children,
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
                        let children = collect_inline(child_elem, ctx, &style);
                        if !children.is_empty() {
                            out.push(RenderNode::Paragraph {
                                children,
                                margin_top_em: style.margin_top_em.unwrap_or(0.0),
                                margin_bottom_em: style.margin_bottom_em.unwrap_or(0.5),
                                margin_left_em: style.margin_left_em.unwrap_or(0.0),
                                margin_right_em: style.margin_right_em.unwrap_or(0.0),
                                align: style.text_align.unwrap_or(TextAlign::Left),
                                text_indent_em: style.text_indent_em,
                                line_height_em: style.line_height_em,
                                padding_em: style.padding_em,
                                background_color: style.background_color,
                            });
                        }
                    }

                    "strong" | "b" | "em" | "i" | "cite" | "dfn" | "a" | "u" | "small"
                    | "sub" | "sup" | "abbr" | "mark" | "del" | "ins" | "s" => {
                        let mut sub = inherit_ctx(ctx, &style);
                        if filter::is_bold_tag(&tag) {
                            sub.bold = true;
                        }
                        if filter::is_italic_tag(&tag) {
                            sub.italic = true;
                        }
                        if filter::is_underline_tag(&tag) {
                            sub.underline = true;
                        }
                        if filter::is_strikethrough_tag(&tag) {
                            sub.line_through = true;
                        }
                        walk_children_of_node(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }

                    "br" => {
                        out.push(RenderNode::LineBreak);
                    }

                    "hr" => {
                        out.push(RenderNode::HorizontalRule);
                    }

                    "img" => {
                        let alt = child_elem.value().attr("alt").map(|s| s.to_string());
                        let img = resolve_img(child_elem, ctx);
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
                        walk_children_of_node(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }

                    "ol" | "ul" => {
                        let ordered = tag == "ol";
                        let items = collect_list_items(child_elem, ctx);
                        if !items.is_empty() {
                            out.push(RenderNode::List {
                                ordered,
                                items,
                                list_style: style.list_style_type,
                            });
                        }
                    }

                    "li" => {
                        let children = collect_inline(child_elem, ctx, &style);
                        if !children.is_empty() {
                            out.push(RenderNode::Paragraph {
                                children,
                                margin_top_em: 0.0,
                                margin_bottom_em: 0.3,
                                margin_left_em: style.margin_left_em.unwrap_or(0.0),
                                margin_right_em: style.margin_right_em.unwrap_or(0.0),
                                align: TextAlign::Left,
                                text_indent_em: style.text_indent_em,
                                line_height_em: style.line_height_em,
                                padding_em: style.padding_em,
                                background_color: style.background_color,
                            });
                        }
                    }

                    "table" => {
                        let rows = collect_table_rows(child_elem, ctx);
                        if !rows.is_empty() {
                            out.push(RenderNode::Table { rows });
                        }
                    }

                    "blockquote" => {
                        let mut children = Vec::new();
                        let mut sub = inherit_ctx(ctx, &style);
                        sub.italic = true;
                        walk_children_of_node(child_elem, &mut sub, &mut children);
                        *ctx.char_offset = *sub.char_offset;
                        if !children.is_empty() {
                            out.push(RenderNode::BlockQuote {
                                children,
                                background_color: style.background_color,
                            });
                        }
                    }

                    "pre" => {
                        let text = child_elem.text().collect::<String>();
                        if !text.trim().is_empty() {
                            *ctx.char_offset += text.len();
                            out.push(RenderNode::CodeBlock { content: text });
                        }
                    }

                    "code" => {
                        let mut sub = inherit_ctx(ctx, &style);
                        sub.bold = true;
                        walk_children_of_node(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }

                    "thead" | "tbody" | "tfoot" | "tr" | "td" | "th" | "caption"
                    | "colgroup" | "col" => {
                        walk_children_of_node(child_elem, ctx, out);
                    }

                    _ => {
                        walk_children_of_node(child_elem, ctx, out);
                    }
                }
            }
            _ => {}
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
) -> Vec<RenderNode> {
    let mut nodes = Vec::new();
    let mut sub = inherit_ctx(ctx, parent_style);
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
                    });
                }
            }
            Node::Element(el) => {
                let tag = el.name.local.as_ref().to_lowercase();
                if filter::should_discard(&tag) {
                    continue;
                }

                let child_elem = ElementRef::wrap(child).unwrap();
                let classes = element_classes(child_elem);
                let style = css::resolve_styles(ctx.css_map, &tag, &classes);

                match tag.as_str() {
                    "br" => out.push(RenderNode::LineBreak),
                    "img" => {
                        let alt = child_elem.value().attr("alt").map(|s| s.to_string());
                        let img = resolve_img(child_elem, ctx);
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
                        walk_inline_children(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }
                    "em" | "i" | "cite" | "dfn" => {
                        let mut sub = inherit_ctx(ctx, &style);
                        sub.italic = true;
                        walk_inline_children(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }
                    "u" | "ins" => {
                        let mut sub = inherit_ctx(ctx, &style);
                        sub.underline = true;
                        walk_inline_children(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }
                    "del" | "s" => {
                        let mut sub = inherit_ctx(ctx, &style);
                        sub.line_through = true;
                        walk_inline_children(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }
                    _ => {
                        let mut sub = inherit_ctx(ctx, &style);
                        walk_inline_children(child_elem, &mut sub, out);
                        *ctx.char_offset = *sub.char_offset;
                    }
                }
            }
            _ => {}
        }
    }
}

// ---------------------------------------------------------------------------
// List items
// ---------------------------------------------------------------------------

fn collect_list_items(elem: ElementRef, ctx: &mut WalkCtx) -> Vec<ListItem> {
    let mut items = Vec::new();
    for child in elem.children() {
        if let Some(child_elem) = ElementRef::wrap(child) {
            let tag = child_elem.value().name.local.as_ref().to_lowercase();
            if tag == "li" {
                let classes = element_classes(child_elem);
                let style = css::resolve_styles(ctx.css_map, &tag, &classes);
                let children = collect_inline(child_elem, ctx, &style);
                items.push(ListItem { children });
            }
        }
    }
    items
}

// ---------------------------------------------------------------------------
// Table rows
// ---------------------------------------------------------------------------

fn collect_table_rows(elem: ElementRef, ctx: &mut WalkCtx) -> Vec<TableRow> {
    let mut rows = Vec::new();
    collect_table_rows_recursive(elem, ctx, &mut rows);
    rows
}

fn collect_table_rows_recursive(
    elem: ElementRef,
    ctx: &mut WalkCtx,
    rows: &mut Vec<TableRow>,
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
                    collect_table_rows_recursive(child_elem, ctx, rows);
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
                let classes = element_classes(child_elem);
                let style = css::resolve_styles(ctx.css_map, &tag, &classes);
                let mut children = Vec::new();
                let mut sub = inherit_ctx(ctx, &style);
                walk_children_of_node(child_elem, &mut sub, &mut children);
                *ctx.char_offset = *sub.char_offset;
                cells.push(TableCell {
                    children,
                    background_color: style.background_color,
                    padding_em: style.padding_em,
                    border: style.border,
                    vertical_align: style.vertical_align,
                });
            }
        }
    }
    (cells, is_header)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn inherit_ctx<'a>(parent: &'a mut WalkCtx, style: &StyleProps) -> WalkCtx<'a> {
    WalkCtx {
        css_map: parent.css_map,
        image_map: parent.image_map,
        chapter_href: parent.chapter_href,
        char_offset: parent.char_offset,
        bold: style.bold.unwrap_or(parent.bold),
        italic: style.italic.unwrap_or(parent.italic),
        underline: style.underline.unwrap_or(parent.underline),
        line_through: style.line_through.unwrap_or(parent.line_through),
        font_size_em: style.font_size_em.unwrap_or(parent.font_size_em),
        color: style.color.or(parent.color),
    }
}

/// Resolved image info: base64, width_hint, width_px, height_px.
struct ResolvedImage {
    data_base64: Option<String>,
    width_hint: Option<f32>,
    width_px: Option<u32>,
    height_px: Option<u32>,
}

/// Resolve an `<img>` element's `src` to base64 data, dimensions, and optional width hint.
fn resolve_img(elem: ElementRef, ctx: &WalkCtx) -> ResolvedImage {
    let src = match elem.value().attr("src") {
        Some(s) => s,
        None => return ResolvedImage { data_base64: None, width_hint: None, width_px: None, height_px: None },
    };

    // Resolve relative src against the chapter's directory.
    let chapter_dir = ctx.chapter_href.rsplit_once('/').map(|(d, _)| d).unwrap_or("");
    let resolved = normalize_path(&format!("{}/{}", chapter_dir, src));

    // Try resolved path first, then raw src, then just the filename.
    let filename = src.rsplit('/').next().unwrap_or(src);
    let info = ctx.image_map.get(&resolved)
        .or_else(|| ctx.image_map.get(src))
        .or_else(|| ctx.image_map.get(filename));

    let (data_base64, dims) = match info {
        Some((b64, dims)) => (Some(b64.clone()), *dims),
        None => (None, None),
    };

    // Parse width attribute for width_hint (e.g. "50%" → 0.5).
    let width_hint = elem.value().attr("width").and_then(|w| {
        if w.ends_with('%') {
            w.trim_end_matches('%').parse::<f32>().ok().map(|v| v / 100.0)
        } else {
            None
        }
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
            ".." => { parts.pop(); }
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
