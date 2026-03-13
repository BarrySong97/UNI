import 'dart:io';

import 'package:path/path.dart' as p;

import '../../src/rust/api/epub_api.dart' as epub_ffi;

/// Pre-parses an EPUB into cached JSON files via Rust FFI.
///
/// Called at import time. The cached files are then read by
/// [CachedChapterDataSource] when the reader opens.
class EpubPreparseService {
  /// Pre-parse an EPUB and write chapter JSON files to a cache directory.
  ///
  /// Returns the cache directory path.
  Future<String> preparse({
    required String epubPath,
    required String booksDirectory,
    required String bookId,
  }) async {
    final cacheDir = p.join(booksDirectory, '${bookId}_parsed');

    // Skip if already parsed.
    final manifest = File(p.join(cacheDir, 'book.json'));
    if (await manifest.exists()) {
      return cacheDir;
    }

    // Call Rust via FFI — works on iOS/Android/desktop.
    await epub_ffi.batchExport(
      epubPath: epubPath,
      outDir: cacheDir,
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
