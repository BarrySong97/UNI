import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../entities/book-entity.dart';
import '../../services/library/book-profile-entry-service.dart';
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

        final nowReading = _computeNowReading(state);
        final gridBooks = _computeGridBooks(state, nowReading?.id);

        return ShelfPageLayout(
          books: state.books,
          isImporting: state.isImporting,
          progressMap: state.progressMap,
          hasReadingProgress: state.progressUpdatedMap.isNotEmpty,
          emptyMessage: localizations.tr('emptyLibrary'),
          importingMessage: localizations.tr('importingBook'),
          nowReadingBook: nowReading,
          nowReadingProgress: nowReading != null
              ? (state.progressMap[nowReading.id] ?? 0)
              : 0,
          gridBooks: gridBooks,
          onBookTap: (book) => _openBookFromLibrary(book.id),
          onImportTap: () => _pickAndImportBook(context),
          onContinueReadingTap: nowReading != null
              ? () => _navigateToReader(nowReading.id)
              : null,
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

  Future<void> _pickAndImportBook(BuildContext context) async {
    final store = AppProvidersScope.of(context).libraryStore;
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['epub', 'txt', 'pdf', 'mobi', 'azw', 'azw3', 'fb2'],
      allowMultiple: false,
    );
    if (!mounted || picked == null || picked.files.single.path == null) {
      return;
    }

    await store.importBookFromPath(picked.files.single.path!);
    if (!mounted) {
      return;
    }

    final message = store.state.errorMessage ?? store.state.lastImportMessage ?? localizations.tr('importDone');
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _navigateToReader(String bookId) async {
    if (_isNavigatingBook || !mounted) {
      return;
    }
    _isNavigatingBook = true;
    try {
      await Navigator.of(context).pushNamed(RouteNames.reader, arguments: bookId);
    } finally {
      _isNavigatingBook = false;
    }
  }

  Future<void> _openBookFromLibrary(String bookId) async {
    if (_isNavigatingBook || !mounted) {
      return;
    }
    _isNavigatingBook = true;
    try {
      final providers = AppProvidersScope.of(context);
      final target = await providers.bookProfileEntryService.resolveEntry(bookId);
      if (!mounted) {
        return;
      }
      switch (target) {
        case BookProfileEntryTarget.profile:
          await Navigator.of(context).pushNamed(RouteNames.bookDetail, arguments: bookId);
          break;
        case BookProfileEntryTarget.reader:
          await Navigator.of(context).pushNamed(RouteNames.reader, arguments: bookId);
          break;
      }
    } finally {
      _isNavigatingBook = false;
    }
  }
}
