import 'package:flutter/widgets.dart';

import '../../repositories/book/book-repository.dart';
import '../../repositories/chapter/chapter-repository.dart';
import '../../repositories/highlight/highlight-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/library/book-profile-entry-service.dart';
import '../../stores/highlight/highlight-store.dart';
import '../../stores/library/library-store.dart';
import '../../stores/reader/reader-store.dart';
import '../i18n/app-locale.dart';

class AppProviders {
  AppProviders({
    required this.bookRepository,
    required this.chapterRepository,
    required this.progressRepository,
    required this.highlightRepository,
    required this.bookProfileEntryService,
    required this.appLocaleController,
  });

  final BookRepository bookRepository;
  final ChapterRepository chapterRepository;
  final ProgressRepository progressRepository;
  final HighlightRepository highlightRepository;
  final BookProfileEntryService bookProfileEntryService;
  final AppLocaleController appLocaleController;

  late final LibraryStore libraryStore;
  late final ReaderStore readerStore;
  late final HighlightStore highlightStore;

  void registerStores({
    required LibraryStore libraryStore,
    required ReaderStore readerStore,
    required HighlightStore highlightStore,
  }) {
    this.libraryStore = libraryStore;
    this.readerStore = readerStore;
    this.highlightStore = highlightStore;
  }
}

class AppProvidersScope extends InheritedWidget {
  const AppProvidersScope({
    required this.providers,
    required super.child,
    super.key,
  });

  final AppProviders providers;

  static AppProviders of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppProvidersScope>();
    assert(scope != null, 'AppProvidersScope not found in widget tree.');
    return scope!.providers;
  }

  @override
  bool updateShouldNotify(covariant AppProvidersScope oldWidget) {
    return oldWidget.providers != providers;
  }
}
