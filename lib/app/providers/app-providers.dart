import 'package:flutter/widgets.dart';

import '../../repositories/book/book-repository.dart';
import '../../repositories/chapter/chapter-repository.dart';
import '../../repositories/annotation/annotation-repository.dart';
import '../../repositories/highlight/highlight-repository.dart';
import '../../repositories/progress/progress-repository.dart';
import '../../services/library/book-profile-entry-service.dart';
import '../../services/db/app-database.dart';
import '../../services/reader/epub_preparse_service.dart';
import '../../services/ai/ai_settings_service.dart';
import '../../services/phonetics/phonetics_service.dart';
import '../../services/pos/pos_service.dart';
import '../../services/tts/tts_service.dart';
import '../../services/reader/reader-entry-service.dart';
import '../../stores/annotation/annotation-store.dart';
import '../../stores/highlight/highlight-store.dart';
import '../../stores/library/library-store.dart';
import '../../stores/reader/reader_store_manager.dart';
import '../i18n/app-locale.dart';

class AppProviders {
  AppProviders({
    required this.bookRepository,
    required this.chapterRepository,
    required this.progressRepository,
    required this.annotationRepository,
    required this.highlightRepository,
    required this.bookProfileEntryService,
    required this.appLocaleController,
    this.documentsDirectoryPath = '',
    required this.epubPreparseService,
    required this.aiSettingsService,
    required this.ttsService,
    required this.phoneticsService,
    required this.posService,
    required this.database,
    ReaderEntryService? readerEntryService,
  }) : readerEntryService = readerEntryService ?? ReaderEntryService();

  final BookRepository bookRepository;
  final ChapterRepository chapterRepository;
  final ProgressRepository progressRepository;
  final AnnotationRepository annotationRepository;
  final HighlightRepository highlightRepository;
  final BookProfileEntryService bookProfileEntryService;
  final AppLocaleController appLocaleController;
  final String documentsDirectoryPath;
  final EpubPreparseService epubPreparseService;
  final AiSettingsService aiSettingsService;
  final TtsService ttsService;
  final PhoneticsService phoneticsService;
  final PosService posService;
  final AppDatabase database;
  final ReaderEntryService readerEntryService;

  late final AnnotationStore annotationStore;
  late final LibraryStore libraryStore;
  late final HighlightStore highlightStore;
  late final ReaderStoreManager readerStoreManager = ReaderStoreManager(
    progressRepository: progressRepository,
  );

  void registerStores({
    required AnnotationStore annotationStore,
    required LibraryStore libraryStore,
    required HighlightStore highlightStore,
  }) {
    this.annotationStore = annotationStore;
    this.libraryStore = libraryStore;
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
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppProvidersScope>();
    assert(scope != null, 'AppProvidersScope not found in widget tree.');
    return scope!.providers;
  }

  static AppProviders? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppProvidersScope>()
        ?.providers;
  }

  @override
  bool updateShouldNotify(covariant AppProvidersScope oldWidget) {
    return oldWidget.providers != providers;
  }
}
