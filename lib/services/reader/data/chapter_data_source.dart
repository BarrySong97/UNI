import '../models/parsed_chapter.dart';

/// Abstract interface for loading parsed chapter data.
///
/// Phase 1: [ChapterJsonBridge] calls the Rust CLI and parses JSON.
/// Phase 2: FFI bridge via flutter_rust_bridge.
abstract class ChapterDataSource {
  /// Load and parse a single chapter by index.
  Future<ParsedChapter> loadChapter(int chapterIndex);

  /// Load book metadata (title, author, TOC, chapter count).
  Future<ParsedBook> loadBook();
}
