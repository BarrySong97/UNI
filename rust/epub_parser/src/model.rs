use serde::Serialize;

/// Core render node — describes content structure without any rendering parameters.
/// Font sizes use relative `em` units; pixel conversion happens in Flutter.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type")]
pub enum RenderNode {
    Text {
        content: String,
        bold: bool,
        italic: bool,
        underline: bool,
        line_through: bool,
        font_size_em: f32,
        color: Option<u32>,
        /// Global character index across the entire book (for selection & highlight).
        node_index: usize,
        /// Link target (e.g. "#footnote1" or "chapter2.xhtml").
        #[serde(skip_serializing_if = "Option::is_none")]
        href: Option<String>,
        /// Superscript text (e.g. footnote markers).
        #[serde(default, skip_serializing_if = "is_false")]
        superscript: bool,
        /// Subscript text (e.g. chemical formulas).
        #[serde(default, skip_serializing_if = "is_false")]
        subscript: bool,
        /// Inline background highlight (e.g. <mark>).
        #[serde(skip_serializing_if = "Option::is_none")]
        background_color: Option<u32>,
    },
    Image {
        /// Base64-encoded image bytes (populated only when --with-images is set).
        #[serde(skip_serializing_if = "Option::is_none")]
        data_base64: Option<String>,
        alt: Option<String>,
        /// Original width ratio 0.0–1.0 relative to container.
        width_hint: Option<f32>,
        /// Native image width in pixels (read from image header at parse time).
        #[serde(skip_serializing_if = "Option::is_none")]
        width_px: Option<u32>,
        /// Native image height in pixels (read from image header at parse time).
        #[serde(skip_serializing_if = "Option::is_none")]
        height_px: Option<u32>,
    },
    Paragraph {
        children: Vec<RenderNode>,
        margin_top_em: f32,
        margin_bottom_em: f32,
        margin_left_em: f32,
        margin_right_em: f32,
        align: TextAlign,
        #[serde(skip_serializing_if = "Option::is_none")]
        text_indent_em: Option<f32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        line_height_em: Option<f32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        padding_em: Option<f32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        background_color: Option<u32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        color: Option<u32>,
    },
    Heading {
        level: u8,
        children: Vec<RenderNode>,
        margin_top_em: f32,
        margin_bottom_em: f32,
        margin_left_em: f32,
        margin_right_em: f32,
        align: TextAlign,
        #[serde(skip_serializing_if = "Option::is_none")]
        color: Option<u32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        text_indent_em: Option<f32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        line_height_em: Option<f32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        padding_em: Option<f32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        background_color: Option<u32>,
    },
    List {
        ordered: bool,
        items: Vec<ListItem>,
        #[serde(skip_serializing_if = "Option::is_none")]
        list_style: Option<ListStyle>,
    },
    Table {
        rows: Vec<TableRow>,
        #[serde(skip_serializing_if = "Option::is_none")]
        caption: Option<Vec<RenderNode>>,
    },
    BlockQuote {
        children: Vec<RenderNode>,
        #[serde(skip_serializing_if = "Option::is_none")]
        background_color: Option<u32>,
        margin_top_em: f32,
        margin_bottom_em: f32,
        margin_left_em: f32,
        margin_right_em: f32,
    },
    CodeBlock {
        children: Vec<RenderNode>,
        #[serde(skip_serializing_if = "Option::is_none")]
        background_color: Option<u32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        padding_em: Option<f32>,
    },
    LineBreak,
    HorizontalRule,
}

/// Helper for `#[serde(skip_serializing_if)]` on bool fields.
fn is_false(v: &bool) -> bool {
    !v
}

#[derive(Debug, Clone, Serialize)]
pub struct ListItem {
    pub children: Vec<RenderNode>,
    /// Block-level nodes found inside this list item (e.g. nested <ul>/<ol>, <p>).
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub sub_nodes: Vec<RenderNode>,
}

#[derive(Debug, Clone, Serialize)]
pub enum TextAlign {
    Left,
    Center,
    Right,
    Justify,
}

#[derive(Debug, Clone, Serialize)]
pub enum ListStyle {
    Disc,
    Circle,
    Square,
    Decimal,
    LowerAlpha,
    UpperAlpha,
    LowerRoman,
    UpperRoman,
    None,
}

#[derive(Debug, Clone, Serialize)]
pub enum BorderStyle {
    None,
    Solid,
    Dashed,
    Dotted,
}

#[derive(Debug, Clone, Serialize)]
pub struct Border {
    pub width_px: f32,
    pub color: Option<u32>,
    pub style: BorderStyle,
}

#[derive(Debug, Clone, Serialize)]
pub enum VerticalAlign {
    Baseline,
    Super,
    Sub,
    Middle,
}

#[derive(Debug, Clone, Serialize)]
pub struct TableRow {
    pub cells: Vec<TableCell>,
    pub is_header: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TableCell {
    pub children: Vec<RenderNode>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub background_color: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub padding_em: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub border: Option<Border>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vertical_align: Option<VerticalAlign>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub colspan: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rowspan: Option<u32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct BookMetadata {
    pub title: String,
    pub author: String,
    pub language: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cover_image_base64: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TocEntry {
    pub title: String,
    pub href: String,
    pub children: Vec<TocEntry>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Chapter {
    pub index: usize,
    pub title: String,
    pub href: String,
    pub nodes: Vec<RenderNode>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ParsedBook {
    pub metadata: BookMetadata,
    pub toc: Vec<TocEntry>,
    pub chapters: Vec<Chapter>,
}
