import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/i18n/app-localizations.dart';
import '../../app/providers/app-providers.dart';
import '../../app/routes/route-names.dart';
import 'library-page-layout.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
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

        return LibraryPageLayout(
          books: state.filteredBooks,
          categories: state.categories,
          activeCategory: state.activeCategory,
          isImporting: state.isImporting,
          onCategoryTap: store.setCategory,
          onBookTap: (book) {
            Navigator.of(context).pushNamed(RouteNames.reader, arguments: book.id);
          },
          onImportTap: () => _pickAndImportBook(context),
          onSearchTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.tr('searchComingSoon'))),
            );
          },
          onMenuTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.tr('menuComingSoon'))),
            );
          },
        );
      },
    );
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
}
