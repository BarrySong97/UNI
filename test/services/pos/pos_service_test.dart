import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/pos/pos_service.dart';

void main() {
  group('formatPosLabel', () {
    test('expands single character codes', () {
      expect(formatPosLabel('n'), 'noun');
      expect(formatPosLabel('v'), 'verb');
      expect(formatPosLabel('a'), 'adjective');
      expect(formatPosLabel('r'), 'adverb');
    });

    test('joins multi-character codes in stable order', () {
      expect(formatPosLabel('nv'), 'noun, verb');
      expect(formatPosLabel('nvar'), 'noun, verb, adjective, adverb');
    });

    test('drops unknown characters and dedupes', () {
      expect(formatPosLabel('nx'), 'noun');
      expect(formatPosLabel('nn'), 'noun');
      expect(formatPosLabel(''), '');
    });
  });

  group('PosService.lookup', () {
    PosService buildService(Map<String, String> data) {
      return PosService(
        queryOverride: (word) async => data[word],
      );
    }

    test('returns null before initialize()', () async {
      final service = buildService({'run': 'nv'});
      expect(await service.lookup('run'), isNull);
    });

    test('returns code and label for direct hit', () async {
      final service = buildService({'run': 'nv'});
      await service.initialize();
      final result = await service.lookup('run');
      expect(result, isNotNull);
      expect(result!.code, 'nv');
      expect(result.label, 'noun, verb');
    });

    test('lowercases input before query', () async {
      final service = buildService({'beautiful': 'a'});
      await service.initialize();
      final result = await service.lookup('Beautiful');
      expect(result?.code, 'a');
    });

    test('falls back through inflection candidates for regular plurals',
        () async {
      // Only the lemma is in the dict, the candidate builder must strip the
      // trailing `s` to find it.
      final service = buildService({'book': 'nv'});
      await service.initialize();
      final result = await service.lookup('books');
      expect(result?.label, 'noun, verb');
    });

    test('falls back to past-tense stripping', () async {
      final service = buildService({'walk': 'nv'});
      await service.initialize();
      expect((await service.lookup('walked'))?.code, 'nv');
    });

    test('falls back to -ing stripping', () async {
      final service = buildService({'walk': 'nv'});
      await service.initialize();
      expect((await service.lookup('walking'))?.code, 'nv');
    });

    test('returns null when no candidate matches', () async {
      final service = buildService({});
      await service.initialize();
      expect(await service.lookup('the'), isNull);
    });

    test('treats empty input safely', () async {
      final service = buildService({'': 'n'});
      await service.initialize();
      expect(await service.lookup(''), isNull);
    });
  });
}
