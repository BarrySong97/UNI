use std::fs;

/// Parse an entire EPUB and return all chapters as a JSON string.
pub fn parse_epub_to_json(path: String) -> anyhow::Result<String> {
    let book = epub_parser::parse_epub(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(serde_json::to_string(&book)?)
}

/// Parse a single chapter by spine index and return as JSON string.
pub fn parse_chapter_to_json(path: String, chapter_index: usize) -> anyhow::Result<String> {
    let chapter =
        epub_parser::parse_chapter(&path, chapter_index).map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(serde_json::to_string(&chapter)?)
}

/// Parse only metadata + TOC and return as JSON string.
pub fn parse_metadata_to_json(path: String) -> anyhow::Result<String> {
    let (metadata, toc) =
        epub_parser::parse_epub_metadata(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let output = serde_json::json!({
        "metadata": metadata,
        "toc": toc,
    });
    Ok(serde_json::to_string(&output)?)
}

/// Parse entire EPUB and export all chapters as individual JSON files.
///
/// Creates `out_dir/book.json` (metadata + toc + chapter_count)
/// and `out_dir/chapter_N.json` for each spine entry.
pub fn batch_export(epub_path: String, out_dir: String) -> anyhow::Result<String> {
    let book = epub_parser::parse_epub(&epub_path).map_err(|e| anyhow::anyhow!("{}", e))?;

    fs::create_dir_all(&out_dir)?;

    let chapter_count = book.chapters.len();
    for chapter in &book.chapters {
        let path = format!("{}/chapter_{}.json", out_dir, chapter.index);
        let json = serde_json::to_string(chapter)?;
        fs::write(&path, json)?;
    }

    let spine: Vec<serde_json::Value> = book
        .chapters
        .iter()
        .map(|ch| serde_json::json!({ "index": ch.index, "href": ch.href }))
        .collect();

    let book_manifest = serde_json::json!({
        "parser_version": 4,
        "metadata": book.metadata,
        "toc": book.toc,
        "chapter_count": chapter_count,
        "spine": spine,
    });
    let manifest_path = format!("{}/book.json", out_dir);
    fs::write(&manifest_path, serde_json::to_string(&book_manifest)?)?;

    Ok(format!(
        "Exported {} chapters to {}",
        chapter_count, out_dir
    ))
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
