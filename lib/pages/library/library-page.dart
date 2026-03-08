import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../components/library/library-book-grid.dart';
import '../../components/library/library-header.dart';
import '../../services/library/book-profile-entry-service.dart';
import '../../shared/constants/common-design-tokens.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppProvidersScope.of(context).libraryStore.loadShelf();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppProvidersScope.of(context).libraryStore;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final state = store.state;
        final lastImportedBookId = state.lastImportedBookId;
        if (lastImportedBookId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            store.clearLastImportedBookId();
          });
        }

        if (state.isLoading) {
          return Container(
            color: CommonDesignTokens.pageBackground,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Stack(
          children: <Widget>[
            Container(
              color: CommonDesignTokens.pageBackground,
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LibraryHeader(
                        headerTitle: 'Library',
                        showImportButton: true,
                        isImporting: state.isImporting,
                        onImportTap: () => _pickAndImportBook(context),
                      ),
                      const SizedBox(height: 20),
                      LibraryBookGrid(
                        books: state.filteredBooks,
                        progressMap: state.progressMap,
                        onBookTap: (book) => _openBook(book.id),
                        categories: state.categories,
                        activeCategory: state.activeCategory,
                        onCategoryTap: (category) => store.setCategory(category),
                        lastImportedBookId: lastImportedBookId,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.isImporting)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: CommonDesignTokens.pageBackground,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndImportBook(BuildContext context) async {
    final store = AppProvidersScope.of(context).libraryStore;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['epub', 'txt', 'pdf', 'mobi', 'azw', 'azw3', 'fb2'],
      allowMultiple: false,
    );
    if (!mounted || picked == null || picked.files.single.path == null) {
      return;
    }

    await store.importBookFromPath(picked.files.single.path!);
  }

  Future<void> _openBook(String bookId) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    try {
      final providers = AppProvidersScope.of(context);
      final progressMap = providers.libraryStore.state.progressMap;
      final target = providers.bookProfileEntryService.resolveEntry(bookId, progressMap);
      if (!mounted) return;
      switch (target) {
        case BookProfileEntryTarget.profile:
          await Navigator.of(context).pushNamed(RouteNames.bookDetail, arguments: bookId);
          break;
        case BookProfileEntryTarget.reader:
          await Navigator.of(context).pushNamed(RouteNames.reader, arguments: bookId);
          break;
      }
    } finally {
      _isNavigating = false;
    }
  }
}
