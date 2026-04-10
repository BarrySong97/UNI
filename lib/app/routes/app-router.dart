import 'package:flutter/material.dart';

import '../../pages/statistics/statistics-page.dart';
import '../../pages/statistics/statistics-types.dart';
import '../../pages/word-of-day/word-of-day-page.dart';
import '../../pages/library/book-detail-page.dart';
import '../../pages/shelf/shelf-page.dart';
import '../../pages/shell/main-tab-shell-page.dart';
import 'route-names.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.mainTabs:
        return MaterialPageRoute<void>(
          builder: (_) => const MainTabShellPage(),
        );
      case RouteNames.shelf:
        return MaterialPageRoute<void>(builder: (_) => const ShelfPage());
      case RouteNames.library:
        return MaterialPageRoute<void>(
          builder: (_) => const MainTabShellPage(initialIndex: 1),
        );
      case RouteNames.discover:
        return MaterialPageRoute<void>(
          builder: (_) => const MainTabShellPage(initialIndex: 2),
        );
      case RouteNames.bookDetail:
        final bookId = settings.arguments as String?;
        return MaterialPageRoute<void>(
          builder: (_) => BookDetailPage(bookId: bookId ?? ''),
        );
      case RouteNames.statistics:
        final arguments = settings.arguments as StatisticsPageArguments?;
        return MaterialPageRoute<void>(
          builder: (_) => StatisticsPage(arguments: arguments),
        );
      case RouteNames.words:
      case RouteNames.wordOfDay:
        return MaterialPageRoute<void>(builder: (_) => const WordsPage());
      default:
        return null;
    }
  }
}
