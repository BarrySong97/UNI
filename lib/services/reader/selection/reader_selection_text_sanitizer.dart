import '../../../shared/utils/pronunciation_selection_text_utils.dart';

String sanitizeReaderSelectionText(String text) =>
    sanitizePronunciationSelectionText(text);

String sanitizeReaderSelectionForReadAloud(String text) {
  return sanitizePronunciationSelectionForReadAloud(text);
}

bool isReaderWordOrPhraseSelection({
  required String rawSelectedText,
  required String normalizedSelectedText,
}) => isPronunciationWordOrPhraseSelection(
  rawSelectedText: rawSelectedText,
  normalizedSelectedText: normalizedSelectedText,
);

bool isReaderSingleWordSelection(String text) =>
    isPronunciationSingleWordSelection(text);
