import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/progress/progress-repository.dart';
import 'package:uni/services/reader/data/chapter_data_source.dart';
import 'package:uni/services/reader/models/parsed_chapter.dart';
import 'package:uni/services/reader/models/render_node.dart';
import 'package:uni/stores/reader/reader_store.dart';

class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository({this.initial});

  final ReadingProgressEntity? initial;
  ReadingProgressEntity? lastSaved;

  @override
  Future<List<ReadingProgressEntity>> getAllProgress() async {
    return lastSaved == null ? const [] : [lastSaved!];
  }

  @override
  Future<ReadingProgressEntity?> getProgress(String bookId) async {
    if (lastSaved != null && lastSaved!.bookId == bookId) return lastSaved;
    if (initial != null && initial!.bookId == bookId) return initial;
    return null;
  }

  @override
  Future<void> saveProgress(ReadingProgressEntity progress) async {
    lastSaved = progress;
  }
}

class _FakeChapterDataSource implements ChapterDataSource {
  const _FakeChapterDataSource({required this.book, required this.chapters});

  final ParsedBook book;
  final List<ParsedChapter> chapters;

  @override
  Future<ParsedChapter> loadChapter(int chapterIndex) async {
    return chapters[chapterIndex];
  }

  @override
  Future<ParsedBook> loadBook() async => book;
}

Future<void> _waitForAllPages(ReaderStore store) async {
  final sw = Stopwatch()..start();
  while (store.totalBookPages == 0) {
    if (sw.elapsedMilliseconds > 3000) {
      fail('Timed out waiting for totalBookPages to be computed');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

ParsedChapter _chapter({
  required int index,
  required String title,
  required String href,
  required String text,
}) {
  return ParsedChapter(
    index: index,
    title: title,
    href: href,
    nodes: [
      ParagraphNode(children: [TextNode(content: text)]),
    ],
  );
}

BookEntity _bookEntity() {
  final now = DateTime(2024, 1, 1);
  return BookEntity(
    id: 'book-1',
    title: 'Test Book',
    author: 'Test Author',
    sourceType: 'local_epub',
    createdAt: now,
    updatedAt: now,
  );
}

String _longText(int repeat) {
  return List<String>.filled(
    repeat,
    'This is a long paragraph used to force pagination across multiple pages.',
  ).join(' ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'position/read percent semantics and goToBookPercent(1.0) reach end',
    () async {
      final progressRepo = _FakeProgressRepository();
      final store = ReaderStore(progressRepository: progressRepo);

      final chapters = [
        _chapter(
          index: 0,
          title: 'Chapter 1',
          href: 'ch1.xhtml',
          text: _longText(120),
        ),
        _chapter(
          index: 1,
          title: 'Chapter 2',
          href: 'ch2.xhtml',
          text: _longText(120),
        ),
      ];
      final dataSource = _FakeChapterDataSource(
        book: ParsedBook(
          metadata: const BookMetadata(title: 'T', author: 'A'),
          toc: const [
            TocEntry(title: 'Chapter 1', href: 'ch1.xhtml'),
            TocEntry(title: 'Chapter 2', href: 'ch2.xhtml'),
          ],
          chapters: chapters,
        ),
        chapters: chapters,
      );

      await store.openBook(
        book: _bookEntity(),
        dataSource: dataSource,
        viewportSize: const Size(320, 220),
        safeAreaTop: 0,
        safeAreaBottom: 0,
      );
      await _waitForAllPages(store);

      expect(store.totalBookPages, greaterThan(1));

      expect(store.bookPositionPercent, closeTo(0.0, 1e-9));
      expect(store.bookReadPercent, closeTo(1 / store.totalBookPages, 1e-9));
      expect(store.bookPercent, closeTo(store.bookPositionPercent, 1e-9));

      await store.goToBookPercent(0.5);
      final expectedPosition =
          (store.currentBookPage - 1) / (store.totalBookPages - 1);
      final expectedRead = store.currentBookPage / store.totalBookPages;
      expect(store.bookPositionPercent, closeTo(expectedPosition, 1e-9));
      expect(store.bookReadPercent, closeTo(expectedRead, 1e-9));

      await store.goToBookPercent(0.0);
      expect(progressRepo.lastSaved, isNotNull);
      expect(
        progressRepo.lastSaved!.percent,
        closeTo(store.bookReadPercent, 1e-9),
      );
      if (store.totalBookPages > 1) {
        expect(store.bookReadPercent, greaterThan(store.bookPositionPercent));
      }

      await store.goToBookPercent(1.0);
      expect(store.currentBookPage, equals(store.totalBookPages));
      expect(store.bookPositionPercent, closeTo(1.0, 1e-9));
      expect(store.bookReadPercent, closeTo(1.0, 1e-9));
    },
  );

  test(
    'single-page book returns 100% for both position/read percent',
    () async {
      final progressRepo = _FakeProgressRepository();
      final store = ReaderStore(progressRepository: progressRepo);

      final chapter = _chapter(
        index: 0,
        title: 'Only Chapter',
        href: 'ch1.xhtml',
        text: 'Short paragraph.',
      );
      final dataSource = _FakeChapterDataSource(
        book: ParsedBook(
          metadata: const BookMetadata(title: 'T', author: 'A'),
          toc: const [TocEntry(title: 'Only Chapter', href: 'ch1.xhtml')],
          chapters: [chapter],
        ),
        chapters: [chapter],
      );

      await store.openBook(
        book: _bookEntity(),
        dataSource: dataSource,
        viewportSize: const Size(420, 760),
        safeAreaTop: 0,
        safeAreaBottom: 0,
      );
      await _waitForAllPages(store);

      expect(store.totalBookPages, equals(1));
      expect(store.currentBookPage, equals(1));
      expect(store.bookPositionPercent, closeTo(1.0, 1e-9));
      expect(store.bookReadPercent, closeTo(1.0, 1e-9));

      await store.goToBookPercent(1.0);
      expect(store.currentBookPage, equals(1));
      expect(store.bookPositionPercent, closeTo(1.0, 1e-9));
      expect(store.bookReadPercent, closeTo(1.0, 1e-9));
    },
  );

  test('percent values stay clamped while counts are pending', () async {
    final locator = jsonEncode({'chapterIndex': 0, 'pageIndex': 0});
    final progressRepo = _FakeProgressRepository(
      initial: ReadingProgressEntity(
        bookId: 'book-1',
        locatorJson: locator,
        percent: 0.0,
        updatedAt: DateTime(2024, 1, 1),
      ),
    );
    final store = ReaderStore(progressRepository: progressRepo);

    final chapters = [
      _chapter(
        index: 0,
        title: 'Chapter 1',
        href: 'ch1.xhtml',
        text: _longText(80),
      ),
      _chapter(
        index: 1,
        title: 'Chapter 2',
        href: 'ch2.xhtml',
        text: _longText(80),
      ),
    ];
    final dataSource = _FakeChapterDataSource(
      book: ParsedBook(
        metadata: const BookMetadata(title: 'T', author: 'A'),
        toc: const [
          TocEntry(title: 'Chapter 1', href: 'ch1.xhtml'),
          TocEntry(title: 'Chapter 2', href: 'ch2.xhtml'),
        ],
        chapters: chapters,
      ),
      chapters: chapters,
    );

    await store.openBook(
      book: _bookEntity(),
      dataSource: dataSource,
      viewportSize: const Size(320, 220),
      safeAreaTop: 0,
      safeAreaBottom: 0,
    );

    expect(store.bookPositionPercent, greaterThanOrEqualTo(0.0));
    expect(store.bookPositionPercent, lessThanOrEqualTo(1.0));
    expect(store.bookReadPercent, greaterThanOrEqualTo(0.0));
    expect(store.bookReadPercent, lessThanOrEqualTo(1.0));
    expect(store.bookPercent, closeTo(store.bookPositionPercent, 1e-9));
  });
}
