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
  ReadingProgressEntity? lastSaved;

  @override
  Future<List<ReadingProgressEntity>> getAllProgress() async {
    return lastSaved == null ? const [] : <ReadingProgressEntity>[lastSaved!];
  }

  @override
  Future<ReadingProgressEntity?> getProgress(String bookId) async => lastSaved;

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

ParsedChapter _chapter(int index, String href, String text) {
  return ParsedChapter(
    index: index,
    title: 'Chapter ${index + 1}',
    href: href,
    nodes: <RenderNode>[
      ParagraphNode(children: <RenderNode>[TextNode(content: text)]),
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
    'preview jump does not persist progress until later navigation',
    () async {
      final progressRepository = _FakeProgressRepository();
      final store = ReaderStore(progressRepository: progressRepository);

      final chapters = <ParsedChapter>[
        _chapter(0, 'ch0.xhtml', _longText(120)),
        _chapter(1, 'ch1.xhtml', _longText(120)),
      ];
      final dataSource = _FakeChapterDataSource(
        book: ParsedBook(
          metadata: const BookMetadata(title: 'T', author: 'A'),
          toc: const <TocEntry>[
            TocEntry(title: 'Chapter 1', href: 'ch0.xhtml'),
            TocEntry(title: 'Chapter 2', href: 'ch1.xhtml'),
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
      await store.flushProgress();

      final originalLocator = progressRepository.lastSaved!.locatorJson;

      final targetPagination = await store.ensureChapterPagination(1);
      expect(targetPagination, isNotNull);

      await store.goToLocation(
        chapterIndex: 1,
        pageIndexInChapter: 0,
        persistProgress: false,
      );
      await store.flushProgress();

      expect(store.currentChapterIndex, 1);
      expect(progressRepository.lastSaved!.locatorJson, originalLocator);

      store.nextPage();
      await store.flushProgress();

      final updatedLocator =
          jsonDecode(progressRepository.lastSaved!.locatorJson)
              as Map<String, dynamic>;
      expect(updatedLocator['chapterIndex'], 1);
    },
  );
}
