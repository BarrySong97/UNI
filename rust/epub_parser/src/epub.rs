use std::collections::HashMap;

use base64::Engine;
use rbook::Ebook;
use rbook::ebook::manifest::{Manifest, ManifestEntry};
use rbook::ebook::metadata::{Metadata, MetaEntry};
use rbook::ebook::spine::{Spine, SpineEntry};
use rbook::ebook::toc::{Toc, TocEntry as RbookTocEntry, TocChildren};
use rbook::epub::toc::EpubTocEntry;

use crate::css;
use crate::html;

/// Open an EPUB file and parse it into a complete `ParsedBook`.
pub fn open_epub(path: &str) -> Result<crate::model::ParsedBook, Box<dyn std::error::Error>> {
    let epub = rbook::Epub::open(path)?;

    let metadata = extract_metadata(&epub);
    let toc = extract_toc(&epub);

    let mut chapters = Vec::new();
    let mut global_char_offset: usize = 0;

    let all_css = collect_all_css(&epub);
    let image_map = build_image_map(&epub);

    let spine = epub.spine();
    for idx in 0..spine.len() {
        let Some(spine_entry) = spine.by_order(idx) else {
            continue;
        };
        let Some(manifest_entry) = spine_entry.manifest_entry() else {
            continue;
        };
        let href = manifest_entry.href().to_string();

        let xhtml_content = match manifest_entry.read_str() {
            Ok(content) => content,
            Err(_) => continue,
        };

        let css_map = build_css_map(&all_css);
        let nodes = html::parse_xhtml(&xhtml_content, &css_map, &image_map, &href, &mut global_char_offset);
        let title = find_toc_title(&toc, &href).unwrap_or_default();

        chapters.push(crate::model::Chapter {
            index: idx,
            title,
            href,
            nodes,
        });
    }

    Ok(crate::model::ParsedBook {
        metadata,
        toc,
        chapters,
    })
}

/// Parse only metadata and TOC (fast, no chapter content).
pub fn open_epub_metadata(
    path: &str,
) -> Result<(crate::model::BookMetadata, Vec<crate::model::TocEntry>), Box<dyn std::error::Error>> {
    let epub = rbook::Epub::open(path)?;
    let metadata = extract_metadata(&epub);
    let toc = extract_toc(&epub);
    Ok((metadata, toc))
}

/// Parse a single chapter by spine index.
pub fn open_epub_chapter(
    path: &str,
    chapter_index: usize,
) -> Result<crate::model::Chapter, Box<dyn std::error::Error>> {
    let epub = rbook::Epub::open(path)?;
    let toc = extract_toc(&epub);
    let all_css = collect_all_css(&epub);
    let image_map = build_image_map(&epub);

    let spine_entry = epub
        .spine()
        .by_order(chapter_index)
        .ok_or_else(|| format!("Chapter index {} out of range", chapter_index))?;

    let manifest_entry = spine_entry
        .manifest_entry()
        .ok_or_else(|| format!("No manifest entry for spine index {}", chapter_index))?;

    let href = manifest_entry.href().to_string();
    let xhtml_content = manifest_entry.read_str()?;

    let css_map = build_css_map(&all_css);
    let mut char_offset: usize = 0;
    let nodes = html::parse_xhtml(&xhtml_content, &css_map, &image_map, &href, &mut char_offset);
    let title = find_toc_title(&toc, &href).unwrap_or_default();

    Ok(crate::model::Chapter {
        index: chapter_index,
        title,
        href,
        nodes,
    })
}

// ---------------------------------------------------------------------------
// Metadata extraction
// ---------------------------------------------------------------------------

fn extract_metadata(epub: &rbook::Epub) -> crate::model::BookMetadata {
    let metadata = epub.metadata();

    let title = metadata
        .title()
        .map(|t| t.value().to_string())
        .unwrap_or_else(|| "Untitled".to_string());

    let mut author = "Unknown".to_string();
    for c in metadata.creators() {
        author = c.value().to_string();
        break;
    }

    let mut language: Option<String> = None;
    for l in metadata.languages() {
        language = Some(l.value().to_string());
        break;
    }

    let cover_image_base64 = extract_cover_image(epub);

    crate::model::BookMetadata {
        title,
        author,
        language,
        cover_image_base64,
    }
}

fn extract_cover_image(epub: &rbook::Epub) -> Option<String> {
    let cover_entry = epub.manifest().cover_image()?;
    let bytes = cover_entry.read_bytes().ok()?;
    Some(base64::engine::general_purpose::STANDARD.encode(&bytes))
}

// ---------------------------------------------------------------------------
// TOC extraction
// ---------------------------------------------------------------------------

fn extract_toc(epub: &rbook::Epub) -> Vec<crate::model::TocEntry> {
    let Some(root) = epub.toc().contents() else {
        return Vec::new();
    };

    root.children()
        .iter()
        .map(|entry| convert_toc_entry(entry))
        .collect()
}

fn convert_toc_entry(entry: EpubTocEntry) -> crate::model::TocEntry {
    let children: Vec<crate::model::TocEntry> = entry
        .children()
        .iter()
        .map(|c| convert_toc_entry(c))
        .collect();

    let href = entry
        .href()
        .map(|h| h.to_string())
        .unwrap_or_default();

    crate::model::TocEntry {
        title: entry.label().to_string(),
        href,
        children,
    }
}

fn find_toc_title(toc: &[crate::model::TocEntry], href: &str) -> Option<String> {
    for entry in toc {
        let entry_base = entry.href.split('#').next().unwrap_or(&entry.href);
        let href_base = href.split('#').next().unwrap_or(href);
        if entry_base == href_base || entry.href == href {
            return Some(entry.title.clone());
        }
        if let Some(title) = find_toc_title(&entry.children, href) {
            return Some(title);
        }
    }
    None
}

// ---------------------------------------------------------------------------
// Image map — resolve all manifest images to base64
// ---------------------------------------------------------------------------

/// Image data: (base64_string, Option<(width_px, height_px)>).
type ImageInfo = (String, Option<(u32, u32)>);

fn build_image_map(epub: &rbook::Epub) -> HashMap<String, ImageInfo> {
    use std::io::Cursor;
    use image::ImageReader;

    let mut map = HashMap::new();
    for entry in epub.manifest().images() {
        let href = entry.href().to_string();
        if let Ok(bytes) = entry.read_bytes() {
            let b64 = base64::engine::general_purpose::STANDARD.encode(&bytes);

            // Read image dimensions from the header (fast, no full decode).
            let dims = ImageReader::new(Cursor::new(&bytes))
                .with_guessed_format()
                .ok()
                .and_then(|r| r.into_dimensions().ok());

            let info: ImageInfo = (b64, dims);
            // Store both the full href and just the filename for flexible matching.
            let filename = href.rsplit('/').next().unwrap_or(&href).to_string();
            map.insert(href.clone(), info.clone());
            map.insert(filename, info);
        }
    }
    map
}

// ---------------------------------------------------------------------------
// CSS collection
// ---------------------------------------------------------------------------

fn collect_all_css(epub: &rbook::Epub) -> HashMap<String, String> {
    let mut css_contents = HashMap::new();
    for entry in epub.manifest().styles() {
        let href = entry.href().to_string();
        if let Ok(content) = entry.read_str() {
            css_contents.insert(href, content);
        }
    }
    css_contents
}

fn build_css_map(all_css: &HashMap<String, String>) -> HashMap<String, css::StyleProps> {
    let mut merged = HashMap::new();
    for (_href, content) in all_css {
        let parsed = css::parse_css(content);
        for (selector, props) in parsed {
            merged.insert(selector, props);
        }
    }
    merged
}
