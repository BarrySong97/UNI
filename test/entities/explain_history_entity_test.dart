import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/explain-history-entity.dart';

void main() {
  group('ExplainStructuredData.tryParse', () {
    test('parses part of speech from structured explain json', () {
      final data = ExplainStructuredData.tryParse(
        '{"partOfSpeech":"noun","meaningExplain":"clear thinking","detailExplain":["Fits the sentence context."]}',
      );

      expect(data, isNotNull);
      expect(data?.partOfSpeech, 'noun');
      expect(data?.meaningExplain, 'clear thinking');
      expect(data?.detailExplain, <String>['Fits the sentence context.']);
    });

    test('keeps legacy structured explain responses compatible', () {
      final data = ExplainStructuredData.tryParse(
        '{"meaningExplain":"clear thinking","detailExplain":["Fits the sentence context."]}',
      );

      expect(data, isNotNull);
      expect(data?.partOfSpeech, isEmpty);
    });
  });
}
