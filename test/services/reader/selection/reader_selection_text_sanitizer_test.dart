import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/selection/reader_selection_text_sanitizer.dart';

void main() {
  group('sanitizeReaderSelectionText', () {
    test('strips leading and trailing punctuation for explain lookups', () {
      expect(sanitizeReaderSelectionText('  “apple,”  '), 'apple');
      expect(sanitizeReaderSelectionText('...hello?!'), 'hello');
    });

    test('keeps internal punctuation intact', () {
      expect(
        sanitizeReaderSelectionText('"state-of-the-art,"'),
        'state-of-the-art',
      );
      expect(sanitizeReaderSelectionText('《你好，世界！》'), '你好，世界');
    });
  });

  group('sanitizeReaderSelectionForReadAloud', () {
    test('strips boundary sentence punctuation for short selections', () {
      // Boundary-only sentence terminators are treated as accidental
      // over-selection, so normalized text is returned.
      expect(
        sanitizeReaderSelectionForReadAloud('  "I agree."  '),
        'I agree',
      );
    });

    test('trims accidental boundary punctuation for short selections', () {
      expect(sanitizeReaderSelectionForReadAloud('  "apple,"  '), 'apple');
    });
  });

  group('isReaderWordOrPhraseSelection', () {
    test('treats accidental sentence punctuation on a word as a phrase', () {
      expect(
        isReaderWordOrPhraseSelection(
          rawSelectedText: 'apple.',
          normalizedSelectedText: 'apple',
        ),
        isTrue,
      );
    });

    test('treats multi-word selection with boundary period as phrase', () {
      // Boundary-only sentence terminators are accidental over-selection.
      expect(
        isReaderWordOrPhraseSelection(
          rawSelectedText: 'I agree.',
          normalizedSelectedText: 'I agree',
        ),
        isTrue,
      );
    });

    test('treats CJK selection with boundary period as phrase', () {
      // Boundary-only CJK sentence terminators are accidental over-selection.
      expect(
        isReaderWordOrPhraseSelection(
          rawSelectedText: '”这是一个句子。”',
          normalizedSelectedText: '这是一个句子',
        ),
        isTrue,
      );
    });

    test('keeps multi-sentence selections out of word mode', () {
      // Internal sentence terminators still trigger sentence mode.
      expect(
        isReaderWordOrPhraseSelection(
          rawSelectedText: 'He said hello. She waved.',
          normalizedSelectedText: 'He said hello. She waved',
        ),
        isFalse,
      );
    });

    test('keeps phrase selections with boundary commas in word mode', () {
      expect(
        isReaderWordOrPhraseSelection(
          rawSelectedText: '"New York,"',
          normalizedSelectedText: 'New York',
        ),
        isTrue,
      );
    });
  });

  group('isReaderSingleWordSelection', () {
    test('accepts a single normalized word', () {
      expect(isReaderSingleWordSelection('clarity'), isTrue);
      expect(isReaderSingleWordSelection('state-of-the-art'), isTrue);
    });

    test('rejects multi-word selections', () {
      expect(isReaderSingleWordSelection('deep work'), isFalse);
    });

    test('rejects empty selections after sanitizing', () {
      expect(isReaderSingleWordSelection('...'), isFalse);
    });
  });
}
