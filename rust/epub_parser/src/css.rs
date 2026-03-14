use regex::Regex;
use std::collections::HashMap;

use crate::model::{Border, BorderStyle, ListStyle, TextAlign, VerticalAlign};

/// Extracted style properties relevant to rendering.
#[derive(Debug, Clone, Default)]
pub struct StyleProps {
    pub bold: Option<bool>,
    pub italic: Option<bool>,
    pub font_size_em: Option<f32>,
    pub color: Option<u32>,
    pub text_align: Option<TextAlign>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
    pub margin_left_em: Option<f32>,
    pub margin_right_em: Option<f32>,
    pub background_color: Option<u32>,
    pub text_indent_em: Option<f32>,
    pub line_height_em: Option<f32>,
    pub underline: Option<bool>,
    pub line_through: Option<bool>,
    pub padding_em: Option<f32>,
    pub border: Option<Border>,
    pub border_top: Option<Border>,
    pub border_bottom: Option<Border>,
    pub vertical_align: Option<VerticalAlign>,
    pub list_style_type: Option<ListStyle>,
    pub display: Option<String>,
}

/// Parse a CSS string and extract relevant properties per selector.
///
/// Uses simple regex matching — sufficient for typical EPUB stylesheets.
pub fn parse_css(css_content: &str) -> HashMap<String, StyleProps> {
    let mut result = HashMap::new();

    // Match rule blocks: selectors { declarations }
    let rule_re = Regex::new(r"(?s)([^{}]+)\{([^{}]*)\}").unwrap();

    for cap in rule_re.captures_iter(css_content) {
        let selectors_str = cap[1].trim();
        let declarations = &cap[2];

        let props = parse_declarations(declarations);

        for selector in selectors_str.split(',') {
            let key = selector.trim().to_lowercase();
            if !key.is_empty() {
                result.insert(key, props.clone());
            }
        }
    }

    result
}

pub fn parse_declarations(decls: &str) -> StyleProps {
    let mut props = StyleProps::default();

    for decl in decls.split(';') {
        let decl = decl.trim();
        if decl.is_empty() {
            continue;
        }

        let Some((prop, val)) = decl.split_once(':') else {
            continue;
        };
        let prop = prop.trim().to_lowercase();
        let val = val.trim().to_lowercase();

        // Strip !important suffix before processing values.
        let val = if val.contains("!important") {
            val.replace("!important", "").trim().to_string()
        } else {
            val
        };

        // Skip CSS global keywords that require cascade context to resolve.
        if matches!(val.as_str(), "inherit" | "initial" | "unset" | "revert") {
            continue;
        }

        match prop.as_str() {
            "font-weight" => {
                props.bold = Some(
                    val == "bold" || val == "bolder" || val.parse::<u32>().unwrap_or(400) >= 700,
                );
            }
            "font-style" => {
                props.italic = Some(val == "italic" || val.starts_with("oblique"));
            }
            "font-size" => {
                props.font_size_em = parse_length_to_em(&val);
            }
            "text-align" => {
                props.text_align = Some(match val.as_str() {
                    "center" => TextAlign::Center,
                    "right" => TextAlign::Right,
                    "justify" => TextAlign::Justify,
                    _ => TextAlign::Left,
                });
            }
            "margin-top" => {
                props.margin_top_em = parse_length_to_em(&val);
            }
            "margin-bottom" => {
                props.margin_bottom_em = parse_length_to_em(&val);
            }
            "margin-left" => {
                props.margin_left_em = parse_length_to_em(&val);
            }
            "margin-right" => {
                props.margin_right_em = parse_length_to_em(&val);
            }
            "margin" => {
                let (top, right, bottom, left) = parse_margin_shorthand(&val);
                if props.margin_top_em.is_none() {
                    props.margin_top_em = top;
                }
                if props.margin_right_em.is_none() {
                    props.margin_right_em = right;
                }
                if props.margin_bottom_em.is_none() {
                    props.margin_bottom_em = bottom;
                }
                if props.margin_left_em.is_none() {
                    props.margin_left_em = left;
                }
            }
            "color" => {
                props.color = parse_color(&val);
            }
            "background-color" => {
                props.background_color = parse_color(&val);
            }
            "background" => {
                // Extract color component from background shorthand.
                if props.background_color.is_none() {
                    for part in val.split_whitespace() {
                        if part.starts_with('#') || part.starts_with("rgb") {
                            props.background_color = parse_color(part);
                            break;
                        }
                        if let Some(c) = named_color(part) {
                            props.background_color = Some(c);
                            break;
                        }
                    }
                }
            }
            "text-indent" => {
                props.text_indent_em = parse_length_to_em(&val);
            }
            "line-height" => {
                props.line_height_em = parse_line_height(&val);
            }
            "text-decoration" | "text-decoration-line" => {
                if val.contains("underline") {
                    props.underline = Some(true);
                }
                if val.contains("line-through") {
                    props.line_through = Some(true);
                }
                if val == "none" {
                    props.underline = Some(false);
                    props.line_through = Some(false);
                }
            }
            "padding" => {
                // Take the first value as uniform padding.
                let first = val.split_whitespace().next().unwrap_or("");
                props.padding_em = parse_length_to_em(first);
            }
            "padding-top" | "padding-bottom" | "padding-left" | "padding-right" => {
                // For simplicity, any padding-* overrides the uniform value.
                if props.padding_em.is_none() {
                    props.padding_em = parse_length_to_em(&val);
                }
            }
            "border" => {
                props.border = parse_border(&val);
            }
            "border-top" => {
                props.border_top = parse_border(&val);
            }
            "border-bottom" => {
                props.border_bottom = parse_border(&val);
            }
            "vertical-align" => {
                props.vertical_align = match val.as_str() {
                    "super" => Some(VerticalAlign::Super),
                    "sub" => Some(VerticalAlign::Sub),
                    "middle" => Some(VerticalAlign::Middle),
                    "baseline" => Some(VerticalAlign::Baseline),
                    _ => None,
                };
            }
            "list-style-type" | "list-style" => {
                // Tokenize to handle multi-word values like "decimal inside".
                for token in val.split_whitespace() {
                    let found = match token {
                        "disc" => Some(ListStyle::Disc),
                        "circle" => Some(ListStyle::Circle),
                        "square" => Some(ListStyle::Square),
                        "decimal" => Some(ListStyle::Decimal),
                        "lower-alpha" | "lower-latin" => Some(ListStyle::LowerAlpha),
                        "upper-alpha" | "upper-latin" => Some(ListStyle::UpperAlpha),
                        "lower-roman" => Some(ListStyle::LowerRoman),
                        "upper-roman" => Some(ListStyle::UpperRoman),
                        "none" => Some(ListStyle::None),
                        _ => None,
                    };
                    if found.is_some() {
                        props.list_style_type = found;
                        break;
                    }
                }
            }
            "display" => {
                props.display = Some(val.to_string());
            }
            "font" => {
                // font: [style] [variant] [weight] [size[/line-height]] [family...]
                for part in val.split_whitespace() {
                    match part {
                        "bold" | "bolder" => {
                            props.bold = Some(true);
                        }
                        "italic" | "oblique" => {
                            props.italic = Some(true);
                        }
                        _ => {
                            if part.contains('/') {
                                // size/line-height (e.g. "1em/1.6")
                                if let Some((size, lh)) = part.split_once('/') {
                                    if props.font_size_em.is_none() {
                                        props.font_size_em = parse_length_to_em(size);
                                    }
                                    if props.line_height_em.is_none() {
                                        props.line_height_em = parse_line_height(lh);
                                    }
                                }
                            } else if part.ends_with("em")
                                || part.ends_with("px")
                                || part.ends_with('%')
                            {
                                if props.font_size_em.is_none() {
                                    props.font_size_em = parse_length_to_em(part);
                                }
                            } else if let Ok(w) = part.parse::<u32>() {
                                props.bold = Some(w >= 700);
                            }
                        }
                    }
                }
            }
            _ => {}
        }
    }

    props
}

// ---------------------------------------------------------------------------
// Length / color / border parsers
// ---------------------------------------------------------------------------

fn parse_length_to_em(val: &str) -> Option<f32> {
    let val = val.trim();
    if val.ends_with("em") {
        val.trim_end_matches("em").trim_end_matches('r').trim().parse().ok()
    } else if val.ends_with("px") {
        val.trim_end_matches("px").trim().parse::<f32>().ok().map(|px| px / 16.0)
    } else if val.ends_with("pt") {
        // 1pt = 1/72in, 1px = 1/96in → 1pt ≈ 1.333px → pt/12 em (assuming 16px base)
        val.trim_end_matches("pt").trim().parse::<f32>().ok().map(|pt| pt / 12.0)
    } else if val.ends_with('%') {
        val.trim_end_matches('%').trim().parse::<f32>().ok().map(|pct| pct / 100.0)
    } else if val == "0" {
        Some(0.0)
    } else if val == "auto" {
        None
    } else if val == "xx-small" {
        Some(0.5625)
    } else if val == "x-small" {
        Some(0.625)
    } else if val == "small" {
        Some(0.8333)
    } else if val == "medium" {
        Some(1.0)
    } else if val == "large" {
        Some(1.125)
    } else if val == "x-large" {
        Some(1.5)
    } else if val == "xx-large" {
        Some(2.0)
    } else {
        // Try bare number (could be negative, e.g. text-indent: -1.78em already handled above)
        val.parse::<f32>().ok()
    }
}

fn parse_line_height(val: &str) -> Option<f32> {
    let val = val.trim();
    if val == "normal" {
        return None; // Let the renderer use its default.
    }
    if val.ends_with("em") {
        return val.trim_end_matches("em").trim().parse().ok();
    }
    if val.ends_with("px") {
        return val.trim_end_matches("px").trim().parse::<f32>().ok().map(|px| px / 16.0);
    }
    // Percentage support (e.g. "120%" → 1.2).
    if val.ends_with('%') {
        return val
            .trim_end_matches('%')
            .trim()
            .parse::<f32>()
            .ok()
            .map(|pct| pct / 100.0);
    }
    // Unitless number (e.g. "1.5") — treated as multiplier, same as em.
    val.parse::<f32>().ok()
}

fn parse_color(val: &str) -> Option<u32> {
    let val = val.trim();
    if val.starts_with('#') {
        let hex = val.trim_start_matches('#');
        match hex.len() {
            3 => {
                let mut expanded = String::with_capacity(6);
                for c in hex.chars() {
                    expanded.push(c);
                    expanded.push(c);
                }
                u32::from_str_radix(&expanded, 16).ok().map(|rgb| 0xFF000000 | rgb)
            }
            4 => {
                // #rgba → expand each digit, reorder to ARGB
                let chars: Vec<char> = hex.chars().collect();
                let r = hex_pair(chars[0], chars[0])?;
                let g = hex_pair(chars[1], chars[1])?;
                let b = hex_pair(chars[2], chars[2])?;
                let a = hex_pair(chars[3], chars[3])?;
                Some(((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32))
            }
            6 => u32::from_str_radix(hex, 16).ok().map(|rgb| 0xFF000000 | rgb),
            8 => {
                // #rrggbbaa → reorder to ARGB
                let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
                let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
                let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
                let a = u8::from_str_radix(&hex[6..8], 16).ok()?;
                Some(((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32))
            }
            _ => None,
        }
    } else if val.starts_with("rgb") {
        // rgb(r, g, b) or rgba(r, g, b, a)
        let inner = val
            .trim_start_matches("rgba(")
            .trim_start_matches("rgb(")
            .trim_end_matches(')')
            .trim();
        let parts: Vec<&str> = inner.split(',').map(|s| s.trim()).collect();
        if parts.len() >= 3 {
            let r = parts[0].parse::<u8>().ok()?;
            let g = parts[1].parse::<u8>().ok()?;
            let b = parts[2].parse::<u8>().ok()?;
            let a = if parts.len() >= 4 {
                (parts[3].parse::<f32>().unwrap_or(1.0) * 255.0) as u8
            } else {
                255
            };
            Some(((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32))
        } else {
            None
        }
    } else {
        // Named color lookup.
        named_color(val)
    }
}

/// Parse a hex digit pair like ('a', 'a') → 0xAA.
fn hex_pair(hi: char, lo: char) -> Option<u8> {
    let s = format!("{}{}", hi, lo);
    u8::from_str_radix(&s, 16).ok()
}

/// CSS named color → ARGB u32.
fn named_color(name: &str) -> Option<u32> {
    match name {
        // CSS Level 1 (17 colors)
        "black" => Some(0xFF000000),
        "white" => Some(0xFFFFFFFF),
        "red" => Some(0xFFFF0000),
        "green" => Some(0xFF008000),
        "blue" => Some(0xFF0000FF),
        "yellow" => Some(0xFFFFFF00),
        "cyan" | "aqua" => Some(0xFF00FFFF),
        "magenta" | "fuchsia" => Some(0xFFFF00FF),
        "gray" | "grey" => Some(0xFF808080),
        "silver" => Some(0xFFC0C0C0),
        "maroon" => Some(0xFF800000),
        "olive" => Some(0xFF808000),
        "lime" => Some(0xFF00FF00),
        "teal" => Some(0xFF008080),
        "navy" => Some(0xFF000080),
        "purple" => Some(0xFF800080),
        "orange" => Some(0xFFFFA500),
        // Extended colors common in EPUBs
        "brown" => Some(0xFFA52A2A),
        "coral" => Some(0xFFFF7F50),
        "crimson" => Some(0xFFDC143C),
        "darkblue" => Some(0xFF00008B),
        "darkgray" | "darkgrey" => Some(0xFFA9A9A9),
        "darkgreen" => Some(0xFF006400),
        "darkred" => Some(0xFF8B0000),
        "dimgray" | "dimgrey" => Some(0xFF696969),
        "firebrick" => Some(0xFFB22222),
        "forestgreen" => Some(0xFF228B22),
        "gold" => Some(0xFFFFD700),
        "goldenrod" => Some(0xFFDAA520),
        "indigo" => Some(0xFF4B0082),
        "ivory" => Some(0xFFFFFFF0),
        "khaki" => Some(0xFFF0E68C),
        "lavender" => Some(0xFFE6E6FA),
        "lightblue" => Some(0xFFADD8E6),
        "lightcoral" => Some(0xFFF08080),
        "lightgray" | "lightgrey" => Some(0xFFD3D3D3),
        "lightgreen" => Some(0xFF90EE90),
        "lightyellow" => Some(0xFFFFFFE0),
        "linen" => Some(0xFFFAF0E6),
        "midnightblue" => Some(0xFF191970),
        "moccasin" => Some(0xFFFFE4B5),
        "oldlace" => Some(0xFFFDF5E6),
        "orangered" => Some(0xFFFF4500),
        "pink" => Some(0xFFFFC0CB),
        "plum" => Some(0xFFDDA0DD),
        "royalblue" => Some(0xFF4169E1),
        "salmon" => Some(0xFFFA8072),
        "seagreen" => Some(0xFF2E8B57),
        "sienna" => Some(0xFFA0522D),
        "skyblue" => Some(0xFF87CEEB),
        "slategray" | "slategrey" => Some(0xFF708090),
        "steelblue" => Some(0xFF4682B4),
        "tan" => Some(0xFFD2B48C),
        "thistle" => Some(0xFFD8BFD8),
        "tomato" => Some(0xFFFF6347),
        "turquoise" => Some(0xFF40E0D0),
        "violet" => Some(0xFFEE82EE),
        "wheat" => Some(0xFFF5DEB3),
        "whitesmoke" => Some(0xFFF5F5F5),
        "transparent" => Some(0x00000000),
        _ => None,
    }
}

/// Parse CSS margin shorthand: 1, 2, 3, or 4 values → (top, right, bottom, left).
fn parse_margin_shorthand(val: &str) -> (Option<f32>, Option<f32>, Option<f32>, Option<f32>) {
    let parts: Vec<&str> = val.split_whitespace().collect();
    match parts.len() {
        1 => {
            let v = parse_length_to_em(parts[0]);
            (v, v, v, v)
        }
        2 => {
            let vertical = parse_length_to_em(parts[0]);
            let horizontal = parse_length_to_em(parts[1]);
            (vertical, horizontal, vertical, horizontal)
        }
        3 => {
            let top = parse_length_to_em(parts[0]);
            let horizontal = parse_length_to_em(parts[1]);
            let bottom = parse_length_to_em(parts[2]);
            (top, horizontal, bottom, horizontal)
        }
        4 => {
            let top = parse_length_to_em(parts[0]);
            let right = parse_length_to_em(parts[1]);
            let bottom = parse_length_to_em(parts[2]);
            let left = parse_length_to_em(parts[3]);
            (top, right, bottom, left)
        }
        _ => (None, None, None, None),
    }
}

/// Parse a CSS border shorthand like "1px solid #747678".
fn parse_border(val: &str) -> Option<Border> {
    let val = val.trim();
    if val == "none" || val == "0" {
        return Some(Border {
            width_px: 0.0,
            color: None,
            style: BorderStyle::None,
        });
    }

    let parts: Vec<&str> = val.split_whitespace().collect();
    let mut width_px = 1.0f32;
    let mut style = BorderStyle::Solid;
    let mut color = None;

    for part in &parts {
        if part.ends_with("px") {
            if let Ok(w) = part.trim_end_matches("px").parse::<f32>() {
                width_px = w;
            }
        } else if part.starts_with('#') || part.starts_with("rgb") {
            color = parse_color(part);
        } else {
            match *part {
                "solid" => style = BorderStyle::Solid,
                "dashed" => style = BorderStyle::Dashed,
                "dotted" => style = BorderStyle::Dotted,
                "none" => style = BorderStyle::None,
                _ => {
                    // Try named color for border color.
                    if let Some(c) = named_color(part) {
                        color = Some(c);
                    }
                }
            }
        }
    }

    Some(Border {
        width_px,
        color,
        style,
    })
}

/// Look up style properties for a given tag name, class list, optional id, and ancestor stack.
pub fn resolve_styles(
    css_map: &HashMap<String, StyleProps>,
    tag: &str,
    classes: &[String],
    id: Option<&str>,
    ancestors: &[String],
) -> StyleProps {
    let mut merged = StyleProps::default();

    if let Some(props) = css_map.get(tag) {
        merge_props(&mut merged, props);
    }

    for class in classes {
        let class_selector = format!(".{}", class);
        if let Some(props) = css_map.get(&class_selector) {
            merge_props(&mut merged, props);
        }

        let tag_class_selector = format!("{}.{}", tag, class);
        if let Some(props) = css_map.get(&tag_class_selector) {
            merge_props(&mut merged, props);
        }
    }

    // ID selector (e.g. "#chapter-title").
    if let Some(id) = id {
        let id_selector = format!("#{}", id);
        if let Some(props) = css_map.get(&id_selector) {
            merge_props(&mut merged, props);
        }
    }

    // Simple descendant selectors (2-part only, e.g. "blockquote p").
    if !ancestors.is_empty() {
        for (selector, props) in css_map.iter() {
            if !selector.contains(' ') {
                continue;
            }
            let parts: Vec<&str> = selector.split_whitespace().collect();
            if parts.len() != 2 {
                continue;
            }
            let (ancestor_sel, child_sel) = (parts[0], parts[1]);

            // Check if child selector matches current element.
            let child_matches = child_sel == tag
                || classes
                    .iter()
                    .any(|c| format!(".{}", c) == child_sel || format!("{}.{}", tag, c) == child_sel);

            if !child_matches {
                continue;
            }

            // Check if ancestor selector matches any ancestor in the stack.
            let ancestor_matches = ancestors.iter().any(|a| a == ancestor_sel);

            if ancestor_matches {
                merge_props(&mut merged, props);
            }
        }
    }

    merged
}

pub fn merge_props(base: &mut StyleProps, overlay: &StyleProps) {
    if overlay.bold.is_some() {
        base.bold = overlay.bold;
    }
    if overlay.italic.is_some() {
        base.italic = overlay.italic;
    }
    if overlay.font_size_em.is_some() {
        base.font_size_em = overlay.font_size_em;
    }
    if overlay.color.is_some() {
        base.color = overlay.color;
    }
    if overlay.text_align.is_some() {
        base.text_align = overlay.text_align.clone();
    }
    if overlay.margin_top_em.is_some() {
        base.margin_top_em = overlay.margin_top_em;
    }
    if overlay.margin_bottom_em.is_some() {
        base.margin_bottom_em = overlay.margin_bottom_em;
    }
    if overlay.margin_left_em.is_some() {
        base.margin_left_em = overlay.margin_left_em;
    }
    if overlay.margin_right_em.is_some() {
        base.margin_right_em = overlay.margin_right_em;
    }
    if overlay.background_color.is_some() {
        base.background_color = overlay.background_color;
    }
    if overlay.text_indent_em.is_some() {
        base.text_indent_em = overlay.text_indent_em;
    }
    if overlay.line_height_em.is_some() {
        base.line_height_em = overlay.line_height_em;
    }
    if overlay.underline.is_some() {
        base.underline = overlay.underline;
    }
    if overlay.line_through.is_some() {
        base.line_through = overlay.line_through;
    }
    if overlay.padding_em.is_some() {
        base.padding_em = overlay.padding_em;
    }
    if overlay.border.is_some() {
        base.border = overlay.border.clone();
    }
    if overlay.border_top.is_some() {
        base.border_top = overlay.border_top.clone();
    }
    if overlay.border_bottom.is_some() {
        base.border_bottom = overlay.border_bottom.clone();
    }
    if overlay.vertical_align.is_some() {
        base.vertical_align = overlay.vertical_align.clone();
    }
    if overlay.list_style_type.is_some() {
        base.list_style_type = overlay.list_style_type.clone();
    }
    if overlay.display.is_some() {
        base.display = overlay.display.clone();
    }
}
