import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/debug/render_diff_text_normalizer.dart';

void main() {
  test('normalize collapses whitespace and trims', () {
    final normalized = RenderDiffTextNormalizer.normalize(
      '  Hello \n\n world\u00A0\tfrom   EPUB  ',
    );

    expect(normalized, 'Hello world from EPUB');
  });

  test('stableHash is deterministic', () {
    final a = RenderDiffTextNormalizer.stableHash('same input');
    final b = RenderDiffTextNormalizer.stableHash('same input');
    final c = RenderDiffTextNormalizer.stableHash('different input');

    expect(a, b);
    expect(a, isNot(c));
  });
}
