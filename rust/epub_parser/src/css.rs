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

fn parse_declarations(decls: &str) -> StyleProps {
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
                props.list_style_type = match val.as_str() {
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
    // Unitless number (e.g. "1.5") — treated as multiplier, same as em.
    val.parse::<f32>().ok()
}

fn parse_color(val: &str) -> Option<u32> {
    let val = val.trim();
    if val.starts_with('#') {
        let hex = val.trim_start_matches('#');
        let hex = match hex.len() {
            3 => {
                let mut expanded = String::with_capacity(6);
                for c in hex.chars() {
                    expanded.push(c);
                    expanded.push(c);
                }
                expanded
            }
            6 => hex.to_string(),
            _ => return None,
        };
        u32::from_str_radix(&hex, 16).ok().map(|rgb| 0xFF000000 | rgb)
    } else if val.starts_with("rgb") {
        // rgb(r, g, b) or rgba(r, g, b, a)
        let inner = val
            .trim_start_matches("rgba(")
            .trim_start_matches("rgb(")
            .trim_end_matches(')');
        let parts: Vec<&str> = inner.split(',').collect();
        if parts.len() >= 3 {
            let r = parts[0].trim().parse::<u8>().ok()?;
            let g = parts[1].trim().parse::<u8>().ok()?;
            let b = parts[2].trim().parse::<u8>().ok()?;
            let a = if parts.len() >= 4 {
                (parts[3].trim().parse::<f32>().unwrap_or(1.0) * 255.0) as u8
            } else {
                255
            };
            Some(((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32))
        } else {
            None
        }
    } else {
        None
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
                _ => {}
            }
        }
    }

    Some(Border {
        width_px,
        color,
        style,
    })
}

/// Look up style properties for a given tag name and class list.
pub fn resolve_styles(
    css_map: &HashMap<String, StyleProps>,
    tag: &str,
    classes: &[String],
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

    merged
}

fn merge_props(base: &mut StyleProps, overlay: &StyleProps) {
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
}
