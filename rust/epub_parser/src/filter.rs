/// Nodes that carry no reading content — discard entirely including children.
pub fn should_discard(tag: &str) -> bool {
    matches!(
        tag,
        "script"
            | "style"
            | "link"
            | "meta"
            | "head"
            | "form"
            | "input"
            | "iframe"
            | "noscript"
            | "audio"
            | "video"
            | "source"
            | "object"
            | "embed"
    )
}

/// Elements with `position: absolute/fixed` are out of normal flow.
/// Our flow-based reader cannot render them; they are almost always decorative.
pub fn is_out_of_flow(style: &crate::css::StyleProps) -> bool {
    matches!(style.position.as_deref(), Some("absolute") | Some("fixed"))
}

/// Container tags whose own semantics we ignore — we keep their children only.
pub fn should_flatten(tag: &str) -> bool {
    matches!(
        tag,
        "div" | "span" | "section" | "article" | "body" | "html" | "main" | "header" | "footer"
            | "nav" | "aside"
    )
}

/// Tags that produce bold styling on their children.
pub fn is_bold_tag(tag: &str) -> bool {
    matches!(tag, "strong" | "b")
}

/// Tags that produce italic styling on their children.
pub fn is_italic_tag(tag: &str) -> bool {
    matches!(tag, "em" | "i" | "cite" | "dfn")
}

/// Tags that produce underline styling on their children.
pub fn is_underline_tag(tag: &str) -> bool {
    matches!(tag, "u" | "ins" | "a")
}

/// Tags that produce strikethrough styling on their children.
pub fn is_strikethrough_tag(tag: &str) -> bool {
    matches!(tag, "del" | "s")
}

/// Heading level from tag name, or None if not a heading.
pub fn heading_level(tag: &str) -> Option<u8> {
    match tag {
        "h1" => Some(1),
        "h2" => Some(2),
        "h3" => Some(3),
        "h4" => Some(4),
        "h5" => Some(5),
        "h6" => Some(6),
        _ => None,
    }
}
