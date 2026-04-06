import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/annotation/annotation_text_utils.dart';

void main() {
  test('normalizeAnnotationText collapses whitespace and trims', () {
    expect(
      normalizeAnnotationText('  hello \n\n   world \t again  '),
      'hello world again',
    );
  });

  test('normalized text mapping converts normalized offsets back to raw', () {
    final mapping = NormalizedTextMapping.fromRaw('  hello   world  ');
    final normalized = mapping.normalizedText;
    final start = normalized.indexOf('world');
    final end = start + 'world'.length;

    expect(normalized, 'hello world');
    expect(mapping.normalizedToRawBoundary(start), 10);
    expect(mapping.normalizedToRawBoundary(end), 15);
  });
}
