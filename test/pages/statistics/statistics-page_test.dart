import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/pages/statistics/statistics-page.dart';
import 'package:uni/pages/statistics/statistics-types.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/stores/statistics/statistics-store.dart';

void main() {
  testWidgets('renders reading time statistics view with day tracks', (
    tester,
  ) async {
    final database = AppDatabase();
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );
    final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'book-1',
        title: 'The Creative Act',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-1',
        locatorJson: '{}',
        percent: 0.8,
        updatedAt: DateTime(2026, 3, 1),
      ),
    );
    await database.addReadingTime(
      bookId: 'book-1',
      dateKey: '2026-03-01',
      deltaSeconds: 1800,
    );
    await database.addReadingTime(
      bookId: 'book-1',
      dateKey: '2026-03-02',
      deltaSeconds: 120,
    );

    final store = StatisticsStore(
      database: database,
      initialTab: StatisticsTab.readingTime,
      initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
      now: () => DateTime(2026, 3, 20),
    );

    await tester.pumpWidget(MaterialApp(home: StatisticsPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.byType(AnimatedAlign), findsOneWidget);
    expect(find.text('Reading Time'), findsOneWidget);
    expect(find.text('TOTAL TIME'), findsOneWidget);
    expect(find.text('AVG / DAY'), findsOneWidget);
    expect(find.text('Daily Minutes'), findsOneWidget);
    expect(find.text('Reading Heatmap'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('daily-minutes-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('daily-minutes-track-2026-03-01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('daily-minutes-fill-2026-03-02')),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders books read statistics view with qualified and almost there books',
    (tester) async {
      final database = AppDatabase();
      final progressRepository = ProgressRepositoryImpl(
        progressDao: ProgressDao(database: database),
      );
      final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

      Future<void> seedBook(String id, String title) {
        return database.upsertBook(
          BookDto(
            id: id,
            title: title,
            author: 'Author',
            sourceType: 'local_epub',
            createdAtMillis: nowMillis,
            updatedAtMillis: nowMillis,
          ),
        );
      }

      Future<void> seedProgress(String id, double progress) {
        return progressRepository.saveProgress(
          ReadingProgressEntity(
            bookId: id,
            locatorJson: '{}',
            percent: progress,
            updatedAt: DateTime(2026, 3, 1),
          ),
        );
      }

      await seedBook('qualified', 'The Creative Act');
      await seedBook('almost', 'Show Your Work!');
      await seedProgress('qualified', 1.0);
      await seedProgress('almost', 0.35);
      await database.addReadingTime(
        bookId: 'qualified',
        dateKey: '2026-03-02',
        deltaSeconds: 3600,
      );
      await database.addReadingTime(
        bookId: 'almost',
        dateKey: '2026-03-03',
        deltaSeconds: 2700,
      );

      final store = StatisticsStore(
        database: database,
        initialTab: StatisticsTab.booksRead,
        initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
        now: () => DateTime(2026, 3, 20),
      );

      await tester.pumpWidget(MaterialApp(home: StatisticsPage(store: store)));
      await tester.pumpAndSettle();

      expect(find.text('Books Read'), findsWidgets);
      expect(find.text('Qualified Books'), findsOneWidget);
      expect(find.text('The Creative Act'), findsOneWidget);
      expect(find.text('Almost There'), findsOneWidget);
      expect(find.text('Show Your Work!'), findsOneWidget);
    },
  );

  testWidgets(
    'renders books read empty state when selected block has no data',
    (tester) async {
      final database = AppDatabase();
      final store = StatisticsStore(
        database: database,
        initialTab: StatisticsTab.booksRead,
        initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
        now: () => DateTime(2026, 3, 20),
      );

      await tester.pumpWidget(MaterialApp(home: StatisticsPage(store: store)));
      await tester.pumpAndSettle();

      expect(
        find.text('No books qualified in this time block yet.'),
        findsOneWidget,
      );
      expect(find.text('Almost There'), findsOneWidget);
    },
  );

  testWidgets('tabs use sliding thumb and toggle statistics content', (
    tester,
  ) async {
    final database = AppDatabase();
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );
    final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'reading',
        title: 'The Creative Act',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertBook(
      BookDto(
        id: 'qualified',
        title: 'The Book of Joy',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'reading',
        locatorJson: '{}',
        percent: 0.8,
        updatedAt: DateTime(2026, 3, 1),
      ),
    );
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'qualified',
        locatorJson: '{}',
        percent: 1.0,
        updatedAt: DateTime(2026, 3, 1),
      ),
    );
    await database.addReadingTime(
      bookId: 'reading',
      dateKey: '2026-03-01',
      deltaSeconds: 1800,
    );
    await database.addReadingTime(
      bookId: 'reading',
      dateKey: '2026-03-02',
      deltaSeconds: 1200,
    );
    await database.addReadingTime(
      bookId: 'qualified',
      dateKey: '2026-03-02',
      deltaSeconds: 2400,
    );

    final store = StatisticsStore(
      database: database,
      initialTab: StatisticsTab.readingTime,
      initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
      now: () => DateTime(2026, 3, 20),
    );

    await tester.pumpWidget(MaterialApp(home: StatisticsPage(store: store)));
    await tester.pumpAndSettle();

    final thumbFinder = find.byType(AnimatedAlign);
    expect(thumbFinder, findsOneWidget);
    var thumb = tester.widget<AnimatedAlign>(thumbFinder);
    expect(thumb.alignment, Alignment.centerLeft);
    expect(find.text('Daily Minutes'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('statistics-tab-books-read')),
    );
    await tester.pumpAndSettle();

    thumb = tester.widget<AnimatedAlign>(thumbFinder);
    expect(thumb.alignment, Alignment.centerRight);
    expect(find.text('Qualified Books'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('statistics-tab-reading-time')),
    );
    await tester.pumpAndSettle();

    thumb = tester.widget<AnimatedAlign>(thumbFinder);
    expect(thumb.alignment, Alignment.centerLeft);
    expect(find.text('Daily Minutes'), findsOneWidget);
  });

  testWidgets('daily minutes tracks render tiny-minute fill', (tester) async {
    final database = AppDatabase();
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );
    final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'reading',
        title: 'The Creative Act',
        author: 'Author',
        sourceType: 'local_epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'reading',
        locatorJson: '{}',
        percent: 0.5,
        updatedAt: DateTime(2026, 3, 1),
      ),
    );
    await database.addReadingTime(
      bookId: 'reading',
      dateKey: '2026-03-03',
      deltaSeconds: 120,
    );

    final store = StatisticsStore(
      database: database,
      initialTab: StatisticsTab.readingTime,
      initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
      now: () => DateTime(2026, 3, 20),
    );

    await tester.pumpWidget(MaterialApp(home: StatisticsPage(store: store)));
    await tester.pumpAndSettle();

    final trackFinder = find.byKey(
      const ValueKey<String>('daily-minutes-track-2026-03-03'),
    );
    final tinyFillFinder = find.byKey(
      const ValueKey<String>('daily-minutes-fill-2026-03-03'),
    );

    expect(trackFinder, findsOneWidget);
    expect(tinyFillFinder, findsOneWidget);

    final trackBox = tester.renderObject<RenderBox>(trackFinder);
    final fillBox = tester.renderObject<RenderBox>(tinyFillFinder);
    expect(fillBox.size.height, greaterThan(0));
    expect(fillBox.size.height, lessThanOrEqualTo(trackBox.size.height));
  });

  testWidgets('period pill stays overflow-free on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase();
    final store = StatisticsStore(
      database: database,
      initialTab: StatisticsTab.readingTime,
      initialPeriodPreset: StatisticsPeriodPreset.pickedMonth,
      initialPickedMonth: DateTime(2026, 12, 1),
      now: () => DateTime(2026, 3, 20),
    );

    await tester.pumpWidget(MaterialApp(home: StatisticsPage(store: store)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
