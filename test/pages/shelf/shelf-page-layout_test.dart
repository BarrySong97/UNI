import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/explain-history-entity.dart';
import 'package:uni/entities/reading-time-entity.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/pages/shelf/shelf-page-layout.dart';
import 'package:uni/pages/statistics/statistics-types.dart';

void main() {
  testWidgets('shows empty state button when shelf has no books', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfPageLayout(
            books: const <BookEntity>[],
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_, __) {},
            onImportTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Add Your First Book'), findsOneWidget);
  });

  testWidgets('shows top linear progress while importing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfPageLayout(
            books: const <BookEntity>[],
            isImporting: true,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_, __) {},
            onImportTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Importing...'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('daily goal card opens statistics with reading time tab', (
    tester,
  ) async {
    StatisticsPageArguments? receivedArguments;
    final book = BookEntity(
      id: 'book-1',
      title: 'Book One',
      author: 'Author',
      sourceType: 'local_epub',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.statistics) {
            receivedArguments = settings.arguments as StatisticsPageArguments?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('statistics')),
            );
          }
          return null;
        },
        home: Scaffold(
          body: ShelfPageLayout(
            books: <BookEntity>[book],
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_, __) {},
            onImportTap: () {},
            hasReadingProgress: true,
            readingTime: ReadingTimeEntity.empty(year: 2026, month: 3),
            booksReadThisYear: 3,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('reading-time-stat-card')),
    );
    await tester.pumpAndSettle();

    expect(find.text('statistics'), findsOneWidget);
    expect(receivedArguments?.initialTab, StatisticsTab.readingTime);
    expect(
      receivedArguments?.initialPeriodPreset,
      StatisticsPeriodPreset.thisMonth,
    );
  });

  testWidgets('books read card opens statistics with books read tab', (
    tester,
  ) async {
    StatisticsPageArguments? receivedArguments;
    final book = BookEntity(
      id: 'book-1',
      title: 'Book One',
      author: 'Author',
      sourceType: 'local_epub',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.statistics) {
            receivedArguments = settings.arguments as StatisticsPageArguments?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('statistics')),
            );
          }
          return null;
        },
        home: Scaffold(
          body: ShelfPageLayout(
            books: <BookEntity>[book],
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_, __) {},
            onImportTap: () {},
            hasReadingProgress: true,
            readingTime: ReadingTimeEntity.empty(year: 2026, month: 3),
            booksReadThisYear: 3,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('books-read-stat-card')),
    );
    await tester.pumpAndSettle();

    expect(find.text('statistics'), findsOneWidget);
    expect(receivedArguments?.initialTab, StatisticsTab.booksRead);
    expect(
      receivedArguments?.initialPeriodPreset,
      StatisticsPeriodPreset.thisMonth,
    );
  });

  testWidgets('shows words prompt card and handles more tap', (tester) async {
    var moreTapped = false;
    final book = BookEntity(
      id: 'book-1',
      title: 'Book One',
      author: 'Author',
      sourceType: 'local_epub',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfPageLayout(
            books: <BookEntity>[book],
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_, __) {},
            onImportTap: () {},
            nowReadingBook: book,
            onWordsMoreTap: () => moreTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Words'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Start building your words list'), findsOneWidget);
    expect(
      find.text('Select a word in Reader and tap Explain.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('More'));
    await tester.tap(find.text('More'));
    await tester.pump();

    expect(moreTapped, isTrue);
  });

  testWidgets('shows latest explain preview in words card', (tester) async {
    final book = BookEntity(
      id: 'book-1',
      title: 'Book One',
      author: 'Author',
      sourceType: 'local_epub',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfPageLayout(
            books: <BookEntity>[book],
            isImporting: false,
            emptyMessage: 'No books yet',
            importingMessage: 'Importing...',
            onBookTap: (_, __) {},
            onImportTap: () {},
            nowReadingBook: book,
            wordsPreview: ExplainHistoryEntity(
              bookId: 'book-1',
              bookTitle: 'Book One',
              chapterIndex: 0,
              selectedText: 'vivid',
              contextSentence: 'The memory stayed vivid.',
              response:
                  '{"meaningExplain":"very clear and strong","detailExplain":["Used here for a memory that stays bright."]}',
              createdAt: DateTime(2026, 3, 2),
            ),
          ),
        ),
      ),
    );

    expect(find.text('vivid'), findsOneWidget);
    expect(find.text('very clear and strong'), findsNothing);
    expect(find.text('Book One'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('words-preview-rich-text')),
      findsOneWidget,
    );
  });
}
