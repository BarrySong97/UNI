import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/entities/reading-time-entity.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/progress-dao.dart';

void main() {
  test(
    'addReadingTime accumulates book totals and monthly daily totals',
    () async {
      final database = AppDatabase();

      await database.addReadingTime(
        bookId: 'book-1',
        dateKey: '2026-03-01',
        deltaSeconds: 120,
      );
      await database.addReadingTime(
        bookId: 'book-1',
        dateKey: '2026-03-01',
        deltaSeconds: 30,
      );
      await database.addReadingTime(
        bookId: 'book-1',
        dateKey: '2026-03-02',
        deltaSeconds: 60,
      );
      await database.addReadingTime(
        bookId: 'book-2',
        dateKey: '2026-03-02',
        deltaSeconds: 90,
      );

      expect(await database.getBookReadingTimeSeconds('book-1'), 210);
      expect(await database.getBookReadingTimeSeconds('book-2'), 90);

      final summary = await database.getMonthlyReadingTime(
        year: 2026,
        month: 3,
      );

      expect(summary, isA<ReadingTimeEntity>());
      expect(summary.totalSeconds, 300);
      expect(summary.dailySeconds[0], 150);
      expect(summary.dailySeconds[1], 150);
      expect(summary.dailySeconds.skip(2).every((value) => value == 0), isTrue);
    },
  );

  test('getBooksReadCountInRange uses time block and thresholds', () async {
    final database = AppDatabase();
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );

    Future<void> saveProgress(String bookId, double percent) {
      return progressRepository.saveProgress(
        ReadingProgressEntity(
          bookId: bookId,
          locatorJson: '{}',
          percent: percent,
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
    }

    await saveProgress('book-a', 0.4); // boundary include
    await saveProgress('book-b', 0.39); // below percent threshold
    await saveProgress('book-c', 0.8); // enough progress but not enough time
    await saveProgress('book-d', 0.9); // enough but outside current year
    await saveProgress('book-e', 1.0); // accumulates across multiple days

    await database.addReadingTime(
      bookId: 'book-a',
      dateKey: '2026-01-01',
      deltaSeconds: 1200,
    );
    await database.addReadingTime(
      bookId: 'book-b',
      dateKey: '2026-02-01',
      deltaSeconds: 2000,
    );
    await database.addReadingTime(
      bookId: 'book-c',
      dateKey: '2026-03-01',
      deltaSeconds: 1199,
    );
    await database.addReadingTime(
      bookId: 'book-d',
      dateKey: '2025-12-31',
      deltaSeconds: 3000,
    );
    await database.addReadingTime(
      bookId: 'book-e',
      dateKey: '2026-04-01',
      deltaSeconds: 700,
    );
    await database.addReadingTime(
      bookId: 'book-e',
      dateKey: '2026-04-02',
      deltaSeconds: 500,
    );
    await database.addReadingTime(
      bookId: 'book-a',
      dateKey: '2027-01-01',
      deltaSeconds: 5000,
    );

    final year2026 = await database.getBooksReadCountInRange(
      startInclusive: DateTime(2026, 1, 1),
      endExclusive: DateTime(2027, 1, 1),
      progressThreshold: 0.4,
      readingTimeThresholdSeconds: 1200,
    );
    expect(year2026, 2); // book-a + book-e

    final aprilRange = await database.getBooksReadCountInRange(
      startInclusive: DateTime(2026, 4, 1),
      endExclusive: DateTime(2026, 5, 1),
      progressThreshold: 0.4,
      readingTimeThresholdSeconds: 1200,
    );
    expect(aprilRange, 1); // only book-e in this month

    final invalidRange = await database.getBooksReadCountInRange(
      startInclusive: DateTime(2026, 5, 1),
      endExclusive: DateTime(2026, 5, 1),
      progressThreshold: 0.4,
      readingTimeThresholdSeconds: 1200,
    );
    expect(invalidRange, 0);
  });

  test(
    'statistics range queries return reading summary and book lists',
    () async {
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

      Future<void> seedProgress(String bookId, double percent) {
        return progressRepository.saveProgress(
          ReadingProgressEntity(
            bookId: bookId,
            locatorJson: '{}',
            percent: percent,
            updatedAt: DateTime(2026, 3, 1),
          ),
        );
      }

      await seedBook('qualified', 'Qualified Book');
      await seedBook('progress-only', 'Progress Only');
      await seedBook('time-only', 'Time Only');

      await seedProgress('qualified', 0.75);
      await seedProgress('progress-only', 0.55);
      await seedProgress('time-only', 0.2);

      await database.addReadingTime(
        bookId: 'qualified',
        dateKey: '2026-03-01',
        deltaSeconds: 900,
      );
      await database.addReadingTime(
        bookId: 'qualified',
        dateKey: '2026-03-02',
        deltaSeconds: 600,
      );
      await database.addReadingTime(
        bookId: 'progress-only',
        dateKey: '2026-03-02',
        deltaSeconds: 600,
      );
      await database.addReadingTime(
        bookId: 'time-only',
        dateKey: '2026-03-03',
        deltaSeconds: 1500,
      );

      final readingStats = await database.getReadingTimeStatisticsInRange(
        startInclusive: DateTime(2026, 3, 1),
        endExclusive: DateTime(2026, 3, 4),
      );
      expect(readingStats.totalSeconds, 3600);
      expect(readingStats.averageSecondsPerDay, 1200);
      expect(readingStats.dailyStats.length, 3);
      expect(readingStats.dailyStats[0].seconds, 900);
      expect(readingStats.dailyStats[1].seconds, 1200);
      expect(readingStats.dailyStats[2].seconds, 1500);

      final booksStats = await database.getBooksReadStatisticsInRange(
        startInclusive: DateTime(2026, 3, 1),
        endExclusive: DateTime(2026, 3, 4),
        progressThreshold: 0.4,
        readingTimeThresholdSeconds: 1200,
      );
      expect(booksStats.qualifiedCount, 1);
      expect(booksStats.qualifiedBooks.single.title, 'Qualified Book');
      expect(booksStats.almostThereBooks.length, 2);
      expect(booksStats.almostThereBooks.first.title, 'Time Only');
      expect(booksStats.almostThereBooks.first.needsMoreProgress, isTrue);
      expect(booksStats.almostThereBooks.last.title, 'Progress Only');
      expect(booksStats.almostThereBooks.last.needsMoreTime, isTrue);
    },
  );
}
