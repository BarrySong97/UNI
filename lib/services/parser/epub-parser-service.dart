import '../../entities/chapter-entity.dart';

class EpubParserService {
  Future<List<ChapterEntity>> parse(
    String rawText, {
    required String bookId,
  }) async {
    return <ChapterEntity>[
      ChapterEntity(
        id: '${bookId}_chapter_0',
        bookId: bookId,
        idx: 0,
        title: 'Imported Chapter',
        content: rawText,
        wordCount: rawText.length,
      ),
    ];
  }
}
