import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/services/reader/models/reader_preferences.dart';

void main() {
  test('toJson/fromJson round-trips default mark appearance', () {
    const prefs = ReaderPreferences(
      defaultMarkColor: '#90CAF9',
      defaultMarkStyle: AnnotationStyle.underline,
    );

    final restored = ReaderPreferences.fromJson(prefs.toJson());

    expect(restored.defaultMarkColor, '#90CAF9');
    expect(restored.defaultMarkStyle, AnnotationStyle.underline);
  });

  test('fromJson falls back to default mark appearance', () {
    final restored = ReaderPreferences.fromJson(<String, dynamic>{});

    expect(restored.defaultMarkColor, '#FFE082');
    expect(restored.defaultMarkStyle, AnnotationStyle.highlight);
  });
}
