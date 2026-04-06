import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../src/rust/api/epub_api.dart' as epub_ffi;

/// Pre-parses an EPUB into cached JSON files via Rust FFI.
///
/// Called at import time. The cached files are then read by
/// [CachedChapterDataSource] when the reader opens.
class EpubPreparseService {
  /// Current parser version.  Increment whenever the Rust parser produces
  /// structurally different output (new fields, bug fixes that change node
  /// trees, etc.).  Must match the value written by `batch_export()` in
  /// `rust/src/api/epub_api.rs`.
  static const int currentParserVersion = 4;

  @visibleForTesting
  static bool shouldReuseCacheManifest(Map<String, dynamic> json) {
    final cachedVersion = json['parser_version'] as int? ?? 1;
    return json.containsKey('spine') && cachedVersion == currentParserVersion;
  }

  /// Pre-parse an EPUB and write chapter JSON files to a cache directory.
  ///
  /// Returns the cache directory path.
  Future<String> preparse({
    required String epubPath,
    required String booksDirectory,
    required String bookId,
  }) async {
    final cacheDir = p.join(booksDirectory, '${bookId}_parsed');

    final manifest = File(p.join(cacheDir, 'book.json'));
    if (await manifest.exists()) {
      try {
        final content = await manifest.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final cachedVersion = json['parser_version'] as int?;
        if (shouldReuseCacheManifest(json)) {
          debugPrint(
            '[ReaderCache] Reusing parsed cache for $bookId '
            'version=$cachedVersion dir=$cacheDir',
          );
          return cacheDir;
        }
        debugPrint(
          '[ReaderCache] Invalidating parsed cache for $bookId '
          'cachedVersion=${cachedVersion ?? 'missing'} '
          'hasSpine=${json.containsKey('spine')} dir=$cacheDir',
        );
        await Directory(cacheDir).delete(recursive: true);
      } catch (error) {
        debugPrint(
          '[ReaderCache] Failed to read cache manifest for $bookId '
          'dir=$cacheDir error=$error',
        );
        await Directory(cacheDir).delete(recursive: true);
      }
    }

    debugPrint(
      '[ReaderCache] Generating parsed cache for $bookId '
      'version=$currentParserVersion dir=$cacheDir',
    );
    await epub_ffi.batchExport(epubPath: epubPath, outDir: cacheDir);
    debugPrint(
      '[ReaderCache] Generated parsed cache for $bookId dir=$cacheDir',
    );

    return cacheDir;
  }

  /// Returns the expected cache directory path for a book.
  String cacheDirForBook(String booksDirectory, String bookId) {
    return p.join(booksDirectory, '${bookId}_parsed');
  }

  /// Check whether a book has already been pre-parsed.
  Future<bool> isCached(String booksDirectory, String bookId) async {
    final manifest = File(
      p.join(booksDirectory, '${bookId}_parsed', 'book.json'),
    );
    return manifest.exists();
  }
}
