import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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

  /// In-memory cache for book.json content (populated by [warmUp]).
  String? _bookJsonCache;

  /// In-memory cache for chapter JSON content (populated by [warmUp]).
  final Map<int, String> _chapterJsonCache = {};

  /// Pre-read book.json and the first chapter into memory.
  ///
  /// Intended to be called fire-and-forget before [Navigator.push] so that
  /// file I/O runs in parallel with the route transition animation (~300ms).
  Future<void> warmUp({int chapterIndex = 0}) async {
    try {
      final bookFile = File('$cacheDir/book.json');
      final chapterFile = File('$cacheDir/chapter_$chapterIndex.json');
      // Read both files concurrently.
      final results = await Future.wait([
        bookFile.readAsString(),
        chapterFile.exists().then(
          (exists) => exists ? chapterFile.readAsString() : Future.value(''),
        ),
      ]);
      _bookJsonCache = results[0];
      if (results[1].isNotEmpty) {
        _chapterJsonCache[chapterIndex] = results[1];
      }
    } catch (_) {
      // Warm-up is best-effort; loadBook/loadChapter will retry from disk.
    }
  }

  @override
  Future<ParsedBook> loadBook() async {
    final jsonStr =
        _bookJsonCache ?? await File('$cacheDir/book.json').readAsString();
    _bookJsonCache = null; // Free memory after use.
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

    // Parse spine href list for TOC→chapter mapping.
    final spineList = json['spine'] as List?;

    // Build lightweight chapter stubs with href from spine data.
    final chapters = List.generate(chapterCount, (i) {
      final spineEntry = (spineList != null && i < spineList.length)
          ? spineList[i] as Map<String, dynamic>
          : null;
      final href = spineEntry?['href'] as String? ?? '';
      return ParsedChapter(index: i, title: '', href: href, nodes: []);
    });

    return ParsedBook(metadata: metadata, toc: toc, chapters: chapters);
  }

  @override
  Future<ParsedChapter> loadChapter(int chapterIndex) async {
    final cachedStr = _chapterJsonCache.remove(chapterIndex);
    final jsonStr = cachedStr ?? await _readChapterFile(chapterIndex);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    _debugLogLegacyChapterShape(chapterIndex, json);
    return ParsedChapter.fromJson(json);
  }

  Future<String> _readChapterFile(int chapterIndex) async {
    final file = File('$cacheDir/chapter_$chapterIndex.json');
    if (!await file.exists()) {
      throw Exception('Chapter $chapterIndex not found in cache: ${file.path}');
    }
    return file.readAsString();
  }

  void _debugLogLegacyChapterShape(
    int chapterIndex,
    Map<String, dynamic> json,
  ) {
    final nodes = json['nodes'];
    if (nodes is! List || nodes.isEmpty) {
      return;
    }

    const blockTypes = {
      'Paragraph',
      'Heading',
      'List',
      'Table',
      'BlockQuote',
      'CodeBlock',
    };

    final samples = <String>[];
    var missingBlockIndexCount = 0;

    for (final node in nodes) {
      if (node is! Map<String, dynamic>) {
        continue;
      }
      final type = node['type'] as String?;
      if (type == null || !blockTypes.contains(type)) {
        continue;
      }
      if (!node.containsKey('block_index')) {
        missingBlockIndexCount++;
        if (samples.length < 3) {
          final childCount = (node['children'] as List?)?.length;
          final itemsCount = (node['items'] as List?)?.length;
          samples.add(
            'type=$type childCount=${childCount ?? '-'} items=${itemsCount ?? '-'}',
          );
        }
      }
    }

    if (missingBlockIndexCount > 0) {
      debugPrint(
        '[ReaderCache] Chapter $chapterIndex loaded from legacy cache '
        'missing block_index on $missingBlockIndexCount nodes. '
        'cacheDir=$cacheDir samples=$samples',
      );
    }
  }
}
