use std::collections::HashMap;
use std::fs::{self, File};
use std::io;
use std::path::Path;

use base64::Engine;
use percent_encoding::{percent_encode, AsciiSet, NON_ALPHANUMERIC};
use rbook::ebook::manifest::{Manifest, ManifestEntry};
use rbook::ebook::metadata::{MetaEntry, Metadata};
use rbook::ebook::spine::{Spine, SpineEntry};
use rbook::ebook::toc::{Toc, TocChildren, TocEntry as RbookTocEntry};
use rbook::epub::manifest::EpubManifestEntry;
use rbook::epub::spine::EpubSpineEntry;
use rbook::epub::toc::EpubTocEntry;
use rbook::Ebook;

use crate::css;
use crate::html;

const EPUB_URI_ASCII_SET: &AsciiSet = &NON_ALPHANUMERIC
    .remove(b'%')
    .remove(b'.')
    .remove(b'/')
    .remove(b':')
    .remove(b'#')
    .remove(b'?')
    .remove(b'-')
    .remove(b'_')
    .remove(b'+')
    .remove(b'~')
    .remove(b'=')
    .remove(b'&');

const READABLE_SPINE_MEDIA_TYPES: [&str; 3] =
    ["application/xhtml+xml", "text/html", "image/svg+xml"];

/// Open an EPUB file and parse it into a complete `ParsedBook`.
pub fn open_epub(path: &str) -> Result<crate::model::ParsedBook, Box<dyn std::error::Error>> {
    with_open_epub(path, |epub| {
        let metadata = extract_metadata(epub);
        let toc = extract_toc(epub);

        let mut chapters = Vec::new();
        let mut global_char_offset: usize = 0;

        let all_css = collect_all_css(epub);
        let image_map = build_image_map(epub);

        let spine = epub.spine();
        for idx in 0..spine.len() {
            let Some(spine_entry) = spine.by_order(idx) else {
                continue;
            };
            let Some(source_entry) = spine_entry.manifest_entry() else {
                continue;
            };
            let source_href = source_entry.href().to_string();
            let Some(content_entry) = resolve_readable_spine_entry(spine_entry) else {
                continue;
            };
            let href = content_entry.href().to_string();

            let xhtml_content = match content_entry.read_str() {
                Ok(content) => content,
                Err(_) => continue,
            };

            let css_map = build_css_map(&all_css);
            let nodes = html::parse_xhtml(
                &xhtml_content,
                &css_map,
                &image_map,
                &href,
                &mut global_char_offset,
            );
            let title = find_toc_title(&toc, &source_href)
                .or_else(|| find_toc_title(&toc, &href))
                .unwrap_or_default();

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
    })
}

/// Parse only metadata and TOC (fast, no chapter content).
pub fn open_epub_metadata(
    path: &str,
) -> Result<(crate::model::BookMetadata, Vec<crate::model::TocEntry>), Box<dyn std::error::Error>> {
    with_open_epub(path, |epub| {
        let metadata = extract_metadata(epub);
        let toc = extract_toc(epub);
        Ok((metadata, toc))
    })
}

/// Parse a single chapter by spine index.
pub fn open_epub_chapter(
    path: &str,
    chapter_index: usize,
) -> Result<crate::model::Chapter, Box<dyn std::error::Error>> {
    with_open_epub(path, |epub| {
        let toc = extract_toc(epub);
        let all_css = collect_all_css(epub);
        let image_map = build_image_map(epub);

        let spine_entry = epub
            .spine()
            .by_order(chapter_index)
            .ok_or_else(|| format!("Chapter index {} out of range", chapter_index))?;

        let source_entry = spine_entry
            .manifest_entry()
            .ok_or_else(|| format!("No manifest entry for spine index {}", chapter_index))?;
        let source_href = source_entry.href().to_string();
        let content_entry = resolve_readable_spine_entry(spine_entry).ok_or_else(|| {
            format!(
                "No readable manifest entry for spine index {}",
                chapter_index
            )
        })?;

        let href = content_entry.href().to_string();
        let xhtml_content = content_entry.read_str()?;

        let css_map = build_css_map(&all_css);
        let mut char_offset: usize = 0;
        let nodes = html::parse_xhtml(
            &xhtml_content,
            &css_map,
            &image_map,
            &href,
            &mut char_offset,
        );
        let title = find_toc_title(&toc, &source_href)
            .or_else(|| find_toc_title(&toc, &href))
            .unwrap_or_default();

        Ok(crate::model::Chapter {
            index: chapter_index,
            title,
            href,
            nodes,
        })
    })
}

fn with_open_epub<T, F>(path: &str, f: F) -> Result<T, Box<dyn std::error::Error>>
where
    F: FnOnce(&rbook::Epub) -> Result<T, Box<dyn std::error::Error>>,
{
    match rbook::Epub::options().strict(false).open(path) {
        Ok(epub) => f(&epub),
        Err(error) => {
            if !should_retry_with_sanitized_archive(&error) {
                return Err(Box::new(error));
            }

            let temp_dir = extract_epub_with_encoded_aliases(path)?;
            let epub = rbook::Epub::options()
                .strict(false)
                .open(temp_dir.path())
                .map_err(|open_error| Box::new(open_error) as Box<dyn std::error::Error>)?;
            f(&epub)
        }
    }
}

fn should_retry_with_sanitized_archive(error: &dyn std::error::Error) -> bool {
    let message = error.to_string();
    message.contains("specified file not found in archive")
        || message.contains("specified file not found in filesystem")
}

fn extract_epub_with_encoded_aliases(
    path: &str,
) -> Result<tempfile::TempDir, Box<dyn std::error::Error>> {
    let temp_dir = tempfile::tempdir()?;
    let file = File::open(path)?;
    let mut archive = zip::ZipArchive::new(file)?;

    for index in 0..archive.len() {
        let mut entry = archive.by_index(index)?;
        let Some(relative_path) = entry.enclosed_name().map(|value| value.to_owned()) else {
            continue;
        };
        let output_path = temp_dir.path().join(&relative_path);

        if entry.is_dir() {
            fs::create_dir_all(&output_path)?;
            continue;
        }

        if let Some(parent) = output_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let mut output_file = File::create(&output_path)?;
        io::copy(&mut entry, &mut output_file)?;
    }

    create_encoded_aliases(temp_dir.path())?;
    Ok(temp_dir)
}

fn create_encoded_aliases(root: &Path) -> Result<(), Box<dyn std::error::Error>> {
    fn walk(current: &Path, root: &Path) -> Result<(), Box<dyn std::error::Error>> {
        for entry in fs::read_dir(current)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_dir() {
                walk(&path, root)?;
                continue;
            }

            let relative = path.strip_prefix(root)?;
            let relative_href = relative.to_string_lossy().replace('\\', "/");
            let encoded_href =
                percent_encode(relative_href.as_bytes(), EPUB_URI_ASCII_SET).to_string();
            if encoded_href == relative_href {
                continue;
            }

            let alias_path = root.join(Path::new(&encoded_href));
            if alias_path.exists() {
                continue;
            }
            if let Some(parent) = alias_path.parent() {
                fs::create_dir_all(parent)?;
            }

            match fs::hard_link(&path, &alias_path) {
                Ok(()) => {}
                Err(_) => {
                    fs::copy(&path, &alias_path)?;
                }
            }
        }

        Ok(())
    }

    walk(root, root)
}

fn resolve_readable_spine_entry<'ebook>(
    spine_entry: EpubSpineEntry<'ebook>,
) -> Option<EpubManifestEntry<'ebook>> {
    let manifest_entry = spine_entry.manifest_entry()?;
    if is_readable_spine_entry(&manifest_entry) {
        return Some(manifest_entry);
    }

    manifest_entry
        .fallbacks()
        .find(|entry| is_readable_spine_entry(entry))
        .or(Some(manifest_entry))
}

fn is_readable_spine_entry(entry: &EpubManifestEntry<'_>) -> bool {
    READABLE_SPINE_MEDIA_TYPES.contains(&entry.media_type())
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

    let href = entry.href().map(|h| h.to_string()).unwrap_or_default();

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
    use image::ImageReader;
    use std::io::Cursor;

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
