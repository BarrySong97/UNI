use std::path::PathBuf;

use epub_parser::model::RenderNode;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("..")
}

#[test]
fn parse_epub_accepts_non_percent_encoded_spine_hrefs_in_lenient_mode() {
    let epub_path = repo_root()
        .join("epubs")
        .join("idpf-samples")
        .join("kusamakura-japanese-vertical-writing.epub");

    let book = epub_parser::parse_epub(epub_path.to_str().unwrap())
        .expect("kusamakura sample should parse in lenient mode");

    assert!(!book.chapters.is_empty());
    assert!(
        book.chapters
            .iter()
            .any(|chapter| chapter.href.contains("%E8%A1%A8%E7%B4%99.xhtml")),
        "expected normalized percent-encoded chapter hrefs"
    );
}

#[test]
fn parse_epub_follows_fallback_chain_for_non_markup_spine_entries() {
    let epub_path = repo_root()
        .join("epubs")
        .join("w3c-tests")
        .join("pub-foreign_json-spine.epub");

    let book = epub_parser::parse_epub(epub_path.to_str().unwrap())
        .expect("foreign JSON spine sample should parse via XHTML fallback");

    assert_eq!(book.chapters.len(), 1);
    assert_eq!(book.chapters[0].title, "Link to main page");
    assert!(
        book.chapters[0].href.ends_with("content_001.xhtml"),
        "expected chapter href to resolve to XHTML fallback, got {}",
        book.chapters[0].href
    );
    assert!(!book.chapters[0].nodes.is_empty());
}

#[test]
fn parse_xhtml_preserves_nested_lists_inside_list_items() {
    let xhtml = r#"
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <ol>
              <li>
                <a href="ch001.xhtml#intro">Introduction</a>
                <ol>
                  <li><a href="ch001.xhtml#contributing">Contributing</a></li>
                </ol>
              </li>
            </ol>
          </body>
        </html>
    "#;

    let mut char_offset = 0;
    let nodes = epub_parser::html::parse_xhtml(
        xhtml,
        &std::collections::HashMap::new(),
        &std::collections::HashMap::new(),
        "/nav.xhtml",
        &mut char_offset,
    );

    let top_list = match &nodes[0] {
        RenderNode::List { items, .. } => items,
        node => panic!("expected top-level list, got {node:?}"),
    };

    assert_eq!(top_list.len(), 1);
    assert_eq!(top_list[0].children.len(), 1);
    match &top_list[0].children[0] {
        RenderNode::Text {
            content,
            underline,
            href,
            ..
        } => {
            assert_eq!(content, "Introduction");
            assert!(*underline, "top-level linked item should stay underlined");
            assert_eq!(href.as_deref(), Some("ch001.xhtml#intro"));
        }
        node => panic!("expected linked text child, got {node:?}"),
    }

    assert_eq!(top_list[0].sub_nodes.len(), 1);
    match &top_list[0].sub_nodes[0] {
        RenderNode::List { ordered, items, .. } => {
            assert!(*ordered, "nested ol should stay ordered");
            assert_eq!(items.len(), 1);
            match &items[0].children[0] {
                RenderNode::Text {
                    content,
                    underline,
                    href,
                    ..
                } => {
                    assert_eq!(content, "Contributing");
                    assert!(*underline, "nested linked item should stay underlined");
                    assert_eq!(href.as_deref(), Some("ch001.xhtml#contributing"));
                }
                node => panic!("expected nested linked text child, got {node:?}"),
            }
        }
        node => panic!("expected nested list, got {node:?}"),
    }
}

#[test]
fn parse_xhtml_keeps_semantic_absolute_positioned_content() {
    let xhtml = r#"
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head>
            <title>Fixed Layout</title>
          </head>
          <body>
            <h1 style="position:absolute; top:10px; left:10px;">Title</h1>
            <p style="position:absolute; top:80px; left:40px;">Page 1</p>
            <img
              style="position:absolute; top:140px; left:40px;"
              src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E"
              alt="Badge"
            />
          </body>
        </html>
    "#;

    let mut char_offset = 0;
    let nodes = epub_parser::html::parse_xhtml(
        xhtml,
        &std::collections::HashMap::new(),
        &std::collections::HashMap::new(),
        "/fixed.xhtml",
        &mut char_offset,
    );

    assert_eq!(
        nodes.len(),
        3,
        "expected semantic absolute-positioned nodes to remain"
    );
    assert!(matches!(nodes[0], RenderNode::Heading { .. }));
    assert!(matches!(nodes[1], RenderNode::Paragraph { .. }));
    assert!(matches!(nodes[2], RenderNode::Image { .. }));
}

#[test]
fn parse_xhtml_skips_landmarks_navigation() {
    let xhtml = r#"
        <html xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <nav epub:type="toc">
              <ol><li><a href="chapter.xhtml">Start</a></li></ol>
            </nav>
            <nav epub:type="landmarks">
              <h2>Guide</h2>
              <ol><li><a href="cover.xhtml">Cover</a></li></ol>
            </nav>
          </body>
        </html>
    "#;

    let mut char_offset = 0;
    let nodes = epub_parser::html::parse_xhtml(
        xhtml,
        &std::collections::HashMap::new(),
        &std::collections::HashMap::new(),
        "/toc.xhtml",
        &mut char_offset,
    );

    assert_eq!(nodes.len(), 1, "landmarks nav should be ignored");
    assert!(matches!(nodes[0], RenderNode::List { .. }));
}
