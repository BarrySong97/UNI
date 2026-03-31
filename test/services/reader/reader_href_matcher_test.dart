import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/models/parsed_chapter.dart';
import 'package:uni/services/reader/reader_href_matcher.dart';

void main() {
  test('resolve matches normalized suffix path and strips fragment', () {
    final index = ReaderHrefIndex.fromChapters([
      const ParsedChapter(
        index: 0,
        title: '',
        href: '/OEBPS/xhtml/content.xhtml',
        nodes: [],
      ),
    ]);

    expect(index.resolve('xhtml/content.xhtml#toc'), 0);
  });

  test('resolve normalizes relative path segments', () {
    final index = ReaderHrefIndex.fromChapters([
      const ParsedChapter(
        index: 0,
        title: '',
        href: 'Text/Chapter1.xhtml',
        nodes: [],
      ),
    ]);

    expect(index.resolve('./Text/Chapter1.xhtml#id'), 0);
  });

  test('resolve falls back to filename when unique', () {
    final index = ReaderHrefIndex.fromChapters([
      const ParsedChapter(
        index: 0,
        title: '',
        href: '/OPS/chapters/content.xhtml',
        nodes: [],
      ),
    ]);

    expect(index.resolve('content.xhtml#section'), 0);
  });

  test('filename fallback is ignored when ambiguous', () {
    final index = ReaderHrefIndex.fromChapters([
      const ParsedChapter(
        index: 0,
        title: '',
        href: '/OPS/A/content.xhtml',
        nodes: [],
      ),
      const ParsedChapter(
        index: 1,
        title: '',
        href: '/OPS/B/content.xhtml',
        nodes: [],
      ),
    ]);

    expect(index.resolve('content.xhtml#section'), isNull);
  });
}
