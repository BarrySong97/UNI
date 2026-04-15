import 'package:flutter_test/flutter_test.dart';
import 'package:uni/shared/utils/pronunciation_selection_text_utils.dart';

void main() {
  group('sanitizePronunciationSelectionText', () {
    test('strips leading and trailing punctuation', () {
      expect(sanitizePronunciationSelectionText('  "clarity,"  '), 'clarity');
    });

    test('keeps internal punctuation intact', () {
      expect(
        sanitizePronunciationSelectionText("state-of-the-art"),
        'state-of-the-art',
      );
    });
  });

  group('sanitizePronunciationSelectionForReadAloud', () {
    test('strips boundary sentence punctuation for read aloud', () {
      // Boundary-only sentence terminators are treated as accidental
      // over-selection, so the normalized (stripped) text is returned.
      expect(
        sanitizePronunciationSelectionForReadAloud(
          'Clarity makes deep work possible.',
        ),
        'Clarity makes deep work possible',
      );
    });

    test('keeps sentence punctuation for multi-sentence selections', () {
      // Internal sentence terminators still trigger sentence mode.
      expect(
        sanitizePronunciationSelectionForReadAloud(
          'He said hello. She waved back.',
        ),
        'He said hello. She waved back.',
      );
    });

    test('trims accidental punctuation for short selections', () {
      expect(
        sanitizePronunciationSelectionForReadAloud(' "clarity." '),
        'clarity',
      );
    });
  });

  group('isPronunciationWordOrPhraseSelection', () {
    test('accepts word selection with boundary punctuation', () {
      expect(
        isPronunciationWordOrPhraseSelection(
          rawSelectedText: ' "ephemeral," ',
          normalizedSelectedText: 'ephemeral',
        ),
        isTrue,
      );
    });

    test('accepts short phrase selection', () {
      expect(
        isPronunciationWordOrPhraseSelection(
          rawSelectedText: 'deep work',
          normalizedSelectedText: 'deep work',
        ),
        isTrue,
      );
    });

    test('rejects sentence-like selection', () {
      expect(
        isPronunciationWordOrPhraseSelection(
          rawSelectedText: 'Clarity makes deep work possible.',
          normalizedSelectedText: 'Clarity makes deep work possible.',
        ),
        isFalse,
      );
    });
  });
}
