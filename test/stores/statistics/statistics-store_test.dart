import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/pages/statistics/statistics-types.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/stores/statistics/statistics-store.dart';

void main() {
  test('resolveTimeBlock supports this month, this year, and picked month', () {
    final now = DateTime(2026, 3, 20);

    final monthBlock = StatisticsStore.resolveTimeBlock(
      StatisticsPeriodPreset.thisMonth,
      null,
      now,
    );
    expect(monthBlock.startInclusive, DateTime(2026, 3, 1));
    expect(monthBlock.endExclusive, DateTime(2026, 4, 1));

    final yearBlock = StatisticsStore.resolveTimeBlock(
      StatisticsPeriodPreset.thisYear,
      null,
      now,
    );
    expect(yearBlock.startInclusive, DateTime(2026, 1, 1));
    expect(yearBlock.endExclusive, DateTime(2027, 1, 1));

    final pickedMonthBlock = StatisticsStore.resolveTimeBlock(
      StatisticsPeriodPreset.pickedMonth,
      DateTime(2025, 11, 12),
      now,
    );
    expect(pickedMonthBlock.startInclusive, DateTime(2025, 11, 1));
    expect(pickedMonthBlock.endExclusive, DateTime(2025, 12, 1));
  });

  test(
    'changing tab keeps the current time block and changing period reloads',
    () async {
      final database = AppDatabase();
      final progressRepository = ProgressRepositoryImpl(
        progressDao: ProgressDao(database: database),
      );
      final nowMillis = DateTime(2026, 3, 1).millisecondsSinceEpoch;

      await database.upsertBook(
        BookDto(
          id: 'book-1',
          title: 'Book One',
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
          percent: 0.5,
          updatedAt: DateTime(2026, 3, 1),
        ),
      );
      await database.addReadingTime(
        bookId: 'book-1',
        dateKey: '2026-03-02',
        deltaSeconds: 1200,
      );
      await database.addReadingTime(
        bookId: 'book-1',
        dateKey: '2026-04-02',
        deltaSeconds: 600,
      );

      final store = StatisticsStore(
        database: database,
        initialTab: StatisticsTab.readingTime,
        initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
        now: () => DateTime(2026, 3, 20),
      );

      await store.initialize();
      final initialBlock = store.timeBlock;
      expect(store.readingTimeData?.totalSeconds, 1200);
      expect(store.booksReadData?.qualifiedCount, 1);

      store.setTab(StatisticsTab.booksRead);
      expect(store.selectedTab, StatisticsTab.booksRead);
      expect(store.timeBlock.startInclusive, initialBlock.startInclusive);
      expect(store.timeBlock.endExclusive, initialBlock.endExclusive);

      await store.setPeriodPreset(StatisticsPeriodPreset.thisYear);
      expect(store.timeBlock.startInclusive, DateTime(2026, 1, 1));
      expect(store.timeBlock.endExclusive, DateTime(2027, 1, 1));
      expect(store.readingTimeData?.totalSeconds, 1800);

      await store.setPickedMonth(DateTime(2026, 4, 10));
      expect(store.selectedPeriodPreset, StatisticsPeriodPreset.pickedMonth);
      expect(store.timeBlock.startInclusive, DateTime(2026, 4, 1));
      expect(store.timeBlock.endExclusive, DateTime(2026, 5, 1));
      expect(store.readingTimeData?.totalSeconds, 600);
      expect(store.booksReadData?.qualifiedCount, 0);
    },
  );
}
