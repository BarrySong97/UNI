String sanitizePronunciationSelectionText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  var start = 0;
  var end = trimmed.length;

  while (start < end &&
      _isPronunciationSelectionBoundaryNoise(trimmed[start])) {
    start += 1;
  }
  while (end > start &&
      _isPronunciationSelectionBoundaryNoise(trimmed[end - 1])) {
    end -= 1;
  }

  return trimmed.substring(start, end).trim();
}

String sanitizePronunciationSelectionForReadAloud(String text) {
  final rawText = text.trim();
  if (rawText.isEmpty) {
    return '';
  }

  final normalizedText = sanitizePronunciationSelectionText(rawText);
  if (normalizedText.isEmpty) {
    return '';
  }

  return isPronunciationWordOrPhraseSelection(
        rawSelectedText: rawText,
        normalizedSelectedText: normalizedText,
      )
      ? normalizedText
      : rawText;
}

bool isPronunciationWordOrPhraseSelection({
  required String rawSelectedText,
  required String normalizedSelectedText,
}) {
  if (normalizedSelectedText.isEmpty || normalizedSelectedText.length > 80) {
    return false;
  }

  if (_containsSentenceTerminator(normalizedSelectedText)) {
    return false;
  }

  return !_looksLikeSentenceSelection(
    rawSelectedText: rawSelectedText,
    normalizedSelectedText: normalizedSelectedText,
  );
}

bool isPronunciationSingleWordSelection(String text) {
  final sanitized = sanitizePronunciationSelectionText(text);
  if (sanitized.isEmpty) {
    return false;
  }

  if (sanitized.contains(RegExp(r'\s'))) {
    return false;
  }

  for (final rune in sanitized.runes) {
    if (_isSentenceTerminatorRune(rune)) {
      return false;
    }
  }

  return true;
}

bool _looksLikeSentenceSelection({
  required String rawSelectedText,
  required String normalizedSelectedText,
}) {
  final trimmedRaw = rawSelectedText.trim();
  if (!_endsWithSentenceTerminator(trimmedRaw)) {
    return false;
  }

  if (normalizedSelectedText.contains(RegExp(r'\s'))) {
    return true;
  }

  var cjkCount = 0;
  for (final rune in normalizedSelectedText.runes) {
    if (_isCjkRune(rune)) {
      cjkCount += 1;
      if (cjkCount >= 6) {
        return true;
      }
    }
  }

  return false;
}

bool _containsSentenceTerminator(String text) {
  for (final rune in text.runes) {
    if (_isSentenceTerminatorRune(rune)) {
      return true;
    }
  }
  return false;
}

bool _endsWithSentenceTerminator(String text) {
  for (var index = text.length - 1; index >= 0; index -= 1) {
    final char = text[index];
    if (RegExp(r'\s').hasMatch(char) || _isTrailingCloser(char)) {
      continue;
    }
    return _isSentenceTerminatorRune(char.codeUnitAt(0));
  }
  return false;
}

bool _isPronunciationSelectionBoundaryNoise(String char) {
  if (RegExp(r'\s').hasMatch(char)) {
    return true;
  }

  final code = char.codeUnitAt(0);
  if ((code >= 0x21 && code <= 0x2F) ||
      (code >= 0x3A && code <= 0x40) ||
      (code >= 0x5B && code <= 0x60) ||
      (code >= 0x7B && code <= 0x7E)) {
    return true;
  }

  return _cjkBoundaryPunctuation.contains(char);
}

bool _isSentenceTerminatorRune(int rune) {
  return rune == 0x2E ||
      rune == 0x21 ||
      rune == 0x3F ||
      rune == 0x3002 ||
      rune == 0xFF01 ||
      rune == 0xFF1F ||
      rune == 0x0A;
}

bool _isTrailingCloser(String char) {
  return _trailingClosers.contains(char);
}

bool _isCjkRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0x20000 && rune <= 0x2A6DF) ||
      (rune >= 0x2A700 && rune <= 0x2B73F) ||
      (rune >= 0x2B740 && rune <= 0x2B81F) ||
      (rune >= 0x2B820 && rune <= 0x2CEAF) ||
      (rune >= 0x2CEB0 && rune <= 0x2EBEF) ||
      (rune >= 0x30000 && rune <= 0x3134F);
}

const String _cjkBoundaryPunctuation =
    '，。！？；：、（）【】《》〈〉「」『』〔〕［］｛｝“”‘’—…～﹏·•｡､｢｣﹁﹂﹃﹄';
const String _trailingClosers = '"\'”’)]}】》〉」』';
