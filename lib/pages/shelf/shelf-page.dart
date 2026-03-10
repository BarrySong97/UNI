import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:path/path.dart' as p;

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/book-entity.dart';
import '../../services/reader/reader-performance-tracker.dart';
import '../../stores/library/library-state.dart';
import 'shelf-page-layout.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  bool _isNavigatingBook = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppProvidersScope.of(context).libraryStore.loadShelf();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final store = AppProvidersScope.of(context).libraryStore;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final state = store.state;
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final lastImportedBookId = state.lastImportedBookId;
        if (lastImportedBookId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            store.clearLastImportedBookId();
          });
        }

        final nowReading = _computeNowReading(state);
        final gridBooks = _computeGridBooks(state, nowReading?.id);

        // Warm up up to three likely books for instant overlay opening.
        final warmCandidates = _computeWarmCandidates(state, nowReading?.id);
        if (warmCandidates.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final ctrl = AppProvidersScope.of(context).readerOverlayController;
            for (final book in warmCandidates) {
              final path = book.epubFilePath;
              if (path == null) continue;
              final resolved = _resolveEpubPath(path);
              ctrl.preloadForBook(
                book.id,
                resolved,
                initialLocatorJson: state.progressLocatorMap[book.id],
              );
            }
          });
        }

        return ShelfPageLayout(
          books: state.books,
          isImporting: state.isImporting,
          progressMap: state.progressMap,
          progressBookIds: state.progressUpdatedMap.keys.toSet(),
          hasReadingProgress: state.progressUpdatedMap.isNotEmpty,
          emptyMessage: localizations.tr('emptyLibrary'),
          importingMessage: localizations.tr('importingBook'),
          nowReadingBook: nowReading,
          nowReadingProgress: nowReading != null
              ? (state.progressMap[nowReading.id] ?? 0)
              : 0,
          gridBooks: gridBooks,
          onBookTap: (book, hasProgress) =>
              _openBookFromLibrary(book.id, hasProgress),
          onImportTap: () => _pickAndImportBook(context),
          onContinueReadingTap: nowReading != null
              ? () => _navigateToReader(nowReading.id)
              : null,
          lastImportedBookId: lastImportedBookId,
        );
      },
    );
  }

  BookEntity? _computeNowReading(LibraryState state) {
    if (state.books.isEmpty) {
      return null;
    }
    if (state.progressUpdatedMap.isEmpty) {
      return state.books.first;
    }
    String? mostRecentBookId;
    DateTime? mostRecentTime;
    for (final entry in state.progressUpdatedMap.entries) {
      if (mostRecentTime == null || entry.value.isAfter(mostRecentTime)) {
        mostRecentTime = entry.value;
        mostRecentBookId = entry.key;
      }
    }
    if (mostRecentBookId == null) {
      return state.books.first;
    }
    try {
      return state.books.firstWhere((b) => b.id == mostRecentBookId);
    } catch (_) {
      return state.books.first;
    }
  }

  String _resolveEpubPath(String storedPath) {
    if (p.isAbsolute(storedPath)) return storedPath;
    final docsPath = AppProvidersScope.of(context).documentsDirectoryPath;
    return p.join(docsPath, storedPath);
  }

  List<BookEntity> _computeGridBooks(LibraryState state, String? nowReadingId) {
    final remaining = state.filteredBooks
        .where((b) => b.id != nowReadingId)
        .toList();

    remaining.sort((a, b) {
      final aTime = state.progressUpdatedMap[a.id];
      final bTime = state.progressUpdatedMap[b.id];
      if (aTime == null && bTime == null) {
        return 0;
      }
      if (aTime == null) {
        return 1;
      }
      if (bTime == null) {
        return -1;
      }
      return bTime.compareTo(aTime);
    });

    return remaining;
  }

  List<BookEntity> _computeWarmCandidates(
    LibraryState state,
    String? nowReadingId,
  ) {
    final sorted = state.books.toList(growable: false)
      ..sort((a, b) {
        final aTime = state.progressUpdatedMap[a.id];
        final bTime = state.progressUpdatedMap[b.id];
        if (aTime == null && bTime == null) {
          return 0;
        }
        if (aTime == null) {
          return 1;
        }
        if (bTime == null) {
          return -1;
        }
        return bTime.compareTo(aTime);
      });

    final result = <BookEntity>[];
    if (nowReadingId != null) {
      final nowReading = sorted.where((b) => b.id == nowReadingId);
      result.addAll(nowReading);
    }
    for (final book in sorted) {
      if (result.length >= 3) {
        break;
      }
      if (book.epubFilePath == null) {
        continue;
      }
      if (result.any((e) => e.id == book.id)) {
        continue;
      }
      result.add(book);
    }
    return result;
  }

  Future<void> _pickAndImportBook(BuildContext context) async {
    final store = AppProvidersScope.of(context).libraryStore;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'epub',
        'txt',
        'pdf',
        'mobi',
        'azw',
        'azw3',
        'fb2',
      ],
      allowMultiple: false,
    );
    if (!mounted || picked == null || picked.files.single.path == null) {
      return;
    }

    await store.importBookFromPath(picked.files.single.path!);
  }

  Future<void> _navigateToReader(String bookId) async {
    ReaderPerf.mark(
      'entry.tap',
      bookId: bookId,
      extras: const <String, Object?>{'source': 'shelf_now_reading'},
    );
    await AppProvidersScope.of(
      context,
    ).readerEntryService.openBook(context, bookId);
  }

  Future<void> _openBookFromLibrary(String bookId, bool hasProgress) async {
    if (_isNavigatingBook || !mounted) {
      return;
    }
    _isNavigatingBook = true;
    try {
      final providers = AppProvidersScope.of(context);
      if (!mounted) {
        return;
      }
      ReaderPerf.mark(
        'entry.tap',
        bookId: bookId,
        extras: <String, Object?>{
          'source': 'shelf_recent',
          'has_progress': hasProgress,
        },
      );
      if (hasProgress) {
        ReaderPerf.mark(
          'entry.tap.route_decision',
          bookId: bookId,
          extras: const <String, Object?>{'target': 'reader'},
        );
        await providers.readerEntryService.openBook(context, bookId);
      } else {
        ReaderPerf.mark(
          'entry.tap.route_decision',
          bookId: bookId,
          extras: const <String, Object?>{'target': 'book_detail'},
        );
        await Navigator.of(
          context,
        ).pushNamed(RouteNames.bookDetail, arguments: bookId);
      }
    } finally {
      _isNavigatingBook = false;
    }
  }
}
