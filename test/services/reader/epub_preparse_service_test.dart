import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/epub_preparse_service.dart';

void main() {
  group('EpubPreparseService.shouldReuseCacheManifest', () {
    test('returns true for current parser version with spine', () {
      expect(
        EpubPreparseService.shouldReuseCacheManifest({
          'parser_version': EpubPreparseService.currentParserVersion,
          'spine': const [],
        }),
        isTrue,
      );
    });

    test('returns false when parser version is missing', () {
      expect(
        EpubPreparseService.shouldReuseCacheManifest({'spine': const []}),
        isFalse,
      );
    });

    test('returns false when spine is missing', () {
      expect(
        EpubPreparseService.shouldReuseCacheManifest({
          'parser_version': EpubPreparseService.currentParserVersion,
        }),
        isFalse,
      );
    });
  });
}
