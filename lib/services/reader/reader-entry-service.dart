import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/providers/app-providers.dart';
import '../../pages/reader/reader_page.dart';
import 'data/cached_chapter_data_source.dart';
import 'reader_navigation_target.dart';

/// Entry point for opening books in the reader.
class ReaderEntryService {
  Future<void> openBook(
    BuildContext context,
    String bookId, {
    ReaderNavigationTarget? navigationTarget,
  }) async {
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
    final epubPath = p.isAbsolute(book.epubFilePath!)
        ? book.epubFilePath!
        : p.join(providers.documentsDirectoryPath, book.epubFilePath!);

    late final String cacheDir;
    try {
      debugPrint(
        '[ReaderEntry] preparse start: ${sw.elapsedMilliseconds}ms '
        'book=${book.id}',
      );
      cacheDir = await providers.epubPreparseService.preparse(
        epubPath: epubPath,
        booksDirectory: booksDir,
        bookId: book.id,
      );
      debugPrint(
        '[ReaderEntry] preparse done: ${sw.elapsedMilliseconds}ms '
        'cacheDir=$cacheDir',
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
          navigationTarget: navigationTarget,
        ),
      ),
    );
  }
}
