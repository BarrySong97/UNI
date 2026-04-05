pub mod css;
pub mod epub;
pub mod filter;
pub mod html;
pub mod model;

pub fn parse_epub(path: &str) -> Result<model::ParsedBook, Box<dyn std::error::Error>> {
    epub::open_epub(path)
}

pub fn parse_epub_metadata(
    path: &str,
) -> Result<(model::BookMetadata, Vec<model::TocEntry>), Box<dyn std::error::Error>> {
    epub::open_epub_metadata(path)
}

pub fn parse_chapter(
    path: &str,
    chapter_index: usize,
) -> Result<model::Chapter, Box<dyn std::error::Error>> {
    epub::open_epub_chapter(path, chapter_index)
}
