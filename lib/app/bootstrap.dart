import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../repositories/book/book-repository-impl.dart';
import '../repositories/chapter/chapter-repository-impl.dart';
import '../repositories/highlight/highlight-repository-impl.dart';
import '../repositories/progress/progress-repository-impl.dart';
import '../services/db/app-database.dart';
import '../services/db/daos/books-dao.dart';
import '../services/db/daos/chapters-dao.dart';
import '../services/db/daos/highlights-dao.dart';
import '../services/db/daos/progress-dao.dart';
import '../services/ai/ai_settings_service.dart';
import '../services/tts/tts_service.dart';
import '../services/library/book-profile-entry-service.dart';
import '../services/parser/book-import-service.dart';
import '../services/reader/epub_preparse_service.dart';
import '../src/rust/frb_generated.dart';
import '../stores/highlight/highlight-store.dart';
import '../stores/library/library-store.dart';
import 'app.dart';
import 'i18n/app-locale.dart';
import 'providers/app-providers.dart';

class AppBootstrapResult {
  AppBootstrapResult({required this.app});

  final Widget app;
}

class AppBootstrap {
  static Future<AppBootstrapResult> initialize() async {
    final database = kIsWeb
        ? AppDatabase()
        : await AppDatabase.openPersistent();
    final booksDao = BooksDao(database: database);
    final chaptersDao = ChaptersDao(database: database);
    final progressDao = ProgressDao(database: database);
    final highlightsDao = HighlightsDao(database: database);

    final bookRepository = BookRepositoryImpl(booksDao: booksDao);
    final chapterRepository = ChapterRepositoryImpl(chaptersDao: chaptersDao);
    final progressRepository = ProgressRepositoryImpl(progressDao: progressDao);
    final highlightRepository = HighlightRepositoryImpl(
      highlightsDao: highlightsDao,
    );
    const bookProfileEntryService = BookProfileEntryService();

    String docsPath = '';
    String booksDirectory = '';
    if (!kIsWeb) {
      final docsDir = await getApplicationDocumentsDirectory();
      docsPath = docsDir.path;
      booksDirectory = p.join(docsPath, 'books');
    }

    final appLocale = AppLocaleController();
    await appLocale.initialize();

    final aiSettings = AiSettingsService();
    await aiSettings.initialize();

    final ttsService = TtsService();
    await ttsService.initialize();

    // Initialize Rust FFI via flutter_rust_bridge.
    await RustLib.init();
    final epubPreparseService = EpubPreparseService();

    final providers = AppProviders(
      bookRepository: bookRepository,
      chapterRepository: chapterRepository,
      progressRepository: progressRepository,
      highlightRepository: highlightRepository,
      bookProfileEntryService: bookProfileEntryService,
      appLocaleController: appLocale,
      documentsDirectoryPath: docsPath,
      epubPreparseService: epubPreparseService,
      aiSettingsService: aiSettings,
      ttsService: ttsService,
    );

    providers.registerStores(
      libraryStore: LibraryStore(
        bookRepository: bookRepository,
        bookImportService: BookImportService(),
        booksDirectory: booksDirectory,
        progressRepository: progressRepository,
        epubPreparseService: epubPreparseService,
      ),
      highlightStore: HighlightStore(highlightRepository: highlightRepository),
    );

    return AppBootstrapResult(app: ImmersedApp(providers: providers));
  }
}
