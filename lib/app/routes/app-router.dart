import 'package:flutter/material.dart';

import '../../pages/highlight/highlight-list-page.dart';
import '../../pages/statistics/statistics-page.dart';
import '../../pages/word-of-day/word-of-day-page.dart';
import '../../pages/library/book-detail-page.dart';
import '../../pages/library/library-page.dart';
import '../../pages/reader/reader-page.dart';
import '../../pages/reader/reader-settings-page.dart';
import '../../pages/shell/main-tab-shell-page.dart';
import 'route-guards.dart';
import 'route-names.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.mainTabs:
        return MaterialPageRoute<void>(builder: (_) => const MainTabShellPage());
      case RouteNames.library:
        return MaterialPageRoute<void>(builder: (_) => const LibraryPage());
      case RouteNames.discover:
        return MaterialPageRoute<void>(builder: (_) => const MainTabShellPage(initialIndex: 1));
      case RouteNames.read:
        return MaterialPageRoute<void>(builder: (_) => const MainTabShellPage(initialIndex: 2));
      case RouteNames.bookDetail:
        final bookId = settings.arguments as String?;
        return MaterialPageRoute<void>(builder: (_) => BookDetailPage(bookId: bookId ?? ''));
      case RouteNames.reader:
        final bookId = settings.arguments as String?;
        if (!RouteGuards.canOpenReader(bookId)) {
          return MaterialPageRoute<void>(builder: (_) => const MainTabShellPage());
        }
        return MaterialPageRoute<void>(builder: (_) => ReaderPage(bookId: bookId!));
      case RouteNames.readerSettings:
        return MaterialPageRoute<void>(builder: (_) => const ReaderSettingsPage());
      case RouteNames.statistics:
        return MaterialPageRoute<void>(builder: (_) => const StatisticsPage());
      case RouteNames.wordOfDay:
        return MaterialPageRoute<void>(builder: (_) => const WordOfDayPage());
      case RouteNames.highlights:
        final args = settings.arguments as Map<String, String>?;
        return MaterialPageRoute<void>(
          builder: (_) => HighlightListPage(
            bookId: args?['bookId'] ?? '',
          ),
        );
      default:
        return null;
    }
  }
}
