import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import '../../components/library/library-book-grid.dart';
import '../../components/library/library-header.dart';
import '../../services/library/book-profile-entry-service.dart';
import '../../shared/constants/library-design-tokens.dart';

class ReadPage extends StatefulWidget {
  const ReadPage({super.key});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
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

        if (state.isLoading) {
          return Container(
            color: LibraryDesignTokens.pageBackground,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          color: LibraryDesignTokens.pageBackground,
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
                  const LibraryHeader(
                    headerTitle: 'Library',
                    showImportButton: false,
                  ),
                  const SizedBox(height: 20),
                  LibraryBookGrid(
                    books: state.filteredBooks,
                    progressMap: state.progressMap,
                    onBookTap: (book) => _openBook(book.id),
                    categories: state.categories,
                    activeCategory: state.activeCategory,
                    onCategoryTap: (category) => store.setCategory(category),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBook(String bookId) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    try {
      final providers = AppProvidersScope.of(context);
      final target = await providers.bookProfileEntryService.resolveEntry(bookId);
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
