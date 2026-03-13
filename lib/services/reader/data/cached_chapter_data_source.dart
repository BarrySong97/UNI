import 'dart:convert';
import 'dart:io';

import '../models/parsed_chapter.dart';
import 'chapter_data_source.dart';

/// Reads pre-parsed chapter JSON files from a cache directory on disk.
///
/// Expected directory structure (produced by `epub_parser --batch-export`):
///   `cacheDir/book.json`          — metadata + toc + chapter_count
///   `cacheDir/chapter_0.json`     — first spine entry
///   `cacheDir/chapter_1.json`     — second spine entry
///   ...
class CachedChapterDataSource implements ChapterDataSource {
  CachedChapterDataSource({required this.cacheDir});

  final String cacheDir;

  @override
  Future<ParsedBook> loadBook() async {
    final file = File('$cacheDir/book.json');
    final jsonStr = await file.readAsString();
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    final metadata = BookMetadata.fromJson(
      json['metadata'] as Map<String, dynamic>,
    );
    final toc =
        (json['toc'] as List?)
            ?.map((e) => TocEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final chapterCount = json['chapter_count'] as int? ?? 0;

    // Build lightweight chapter stubs (no nodes) so ReaderStore knows count.
    final chapters = List.generate(
      chapterCount,
      (i) => ParsedChapter(index: i, title: '', href: '', nodes: []),
    );

    return ParsedBook(metadata: metadata, toc: toc, chapters: chapters);
  }

  @override
  Future<ParsedChapter> loadChapter(int chapterIndex) async {
    final file = File('$cacheDir/chapter_$chapterIndex.json');
    if (!await file.exists()) {
      throw Exception('Chapter $chapterIndex not found in cache: ${file.path}');
    }
    final jsonStr = await file.readAsString();
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ParsedChapter.fromJson(json);
  }
}
