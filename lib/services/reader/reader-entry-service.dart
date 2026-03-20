import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/providers/app-providers.dart';
import '../../pages/reader/reader_page.dart';
import 'data/cached_chapter_data_source.dart';

/// Entry point for opening books in the reader.
class ReaderEntryService {
  Future<void> openBook(BuildContext context, String bookId) async {
    final sw = Stopwatch()..start();
    if (!context.mounted) return;

    final providers = AppProvidersScope.of(context);
    final book = await providers.bookRepository.getBookById(bookId);
    debugPrint('[ReaderEntry] getBookById: ${sw.elapsedMilliseconds}ms');

    if (book == null || !context.mounted) return;

    if (book.epubFilePath == null || book.epubFilePath!.isEmpty) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Open Book'),
          content: const Text('No EPUB file path found for this book.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Resolve paths.
    final booksDir = p.join(providers.documentsDirectoryPath, 'books');
    final cacheDir = p.join(booksDir, '${book.id}_parsed');

    // If cache is missing, run preparse on the fly.
    final manifest = File(p.join(cacheDir, 'book.json'));
    final cacheExists = await manifest.exists();
    debugPrint('[ReaderEntry] cacheDir check: ${sw.elapsedMilliseconds}ms, exists=$cacheExists');
    if (!cacheExists) {
      if (!context.mounted) return;

      // Resolve the EPUB file path.
      final epubPath = p.isAbsolute(book.epubFilePath!)
          ? book.epubFilePath!
          : p.join(providers.documentsDirectoryPath, book.epubFilePath!);

      try {
        await providers.epubPreparseService.preparse(
          epubPath: epubPath,
          booksDirectory: booksDir,
          bookId: book.id,
        );
      } catch (e) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Parse Error'),
            content: Text('Failed to parse EPUB: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;

    final dataSource = CachedChapterDataSource(cacheDir: cacheDir);
    debugPrint('[ReaderEntry] warmUp start: ${sw.elapsedMilliseconds}ms');
    dataSource.warmUp();

    debugPrint('[ReaderEntry] Navigator.push: ${sw.elapsedMilliseconds}ms');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          book: book,
          dataSource: dataSource,
          storeManager: providers.readerStoreManager,
        ),
      ),
    );
  }
}
