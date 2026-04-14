import '../../shared/utils/pronunciation_selection_text_utils.dart';

List<String> buildPhoneticsFallbackCandidates(String input) {
  final candidates = <String>[];
  final seen = <String>{};

  void add(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) {
      return;
    }
    candidates.add(trimmed);
  }

  final original = input.trim();
  add(original);

  final sanitized = sanitizePronunciationSelectionText(input);
  add(sanitized);
  add(sanitized.toLowerCase());

  if (sanitized.isEmpty || _looksLikeLongSentence(sanitized)) {
    return candidates;
  }

  if (sanitized.contains('-')) {
    add(sanitized.replaceAll('-', ' '));
    add(sanitized.replaceAll('-', ''));
  }

  final camelSplit = _splitCamelCase(sanitized);
  add(camelSplit);

  if (_isSingleToken(sanitized)) {
    final ordinal = _normalizeOrdinal(sanitized);
    if (ordinal != null) {
      add(ordinal);
    }

    for (final variant in _buildInflectionFallbacks(sanitized)) {
      add(variant);
    }
  }

  return candidates;
}

String normalizePhoneticsCacheKey(String input) {
  final normalized = sanitizePronunciationSelectionText(
    input,
  ).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  return normalized;
}

bool _looksLikeLongSentence(String text) {
  if (text.contains(RegExp(r'[.!?。！？]'))) {
    return true;
  }
  return RegExp(r'\s+').allMatches(text).length >= 3;
}

bool _isSingleToken(String text) => !RegExp(r'\s').hasMatch(text);

String _splitCamelCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i += 1) {
    final current = value[i];
    if (i > 0 && _shouldInsertCamelBoundary(value, i)) {
      buffer.write(' ');
    }
    buffer.write(current);
  }
  return buffer.toString();
}

bool _shouldInsertCamelBoundary(String value, int index) {
  final previous = value[index - 1];
  final current = value[index];
  final next = index + 1 < value.length ? value[index + 1] : null;

  final previousIsLower = _isLowercaseLetter(previous);
  final currentIsUpper = _isUppercaseLetter(current);
  if (previousIsLower && currentIsUpper) {
    return true;
  }

  final previousIsUpper = _isUppercaseLetter(previous);
  final nextIsLower = next != null && _isLowercaseLetter(next);
  return previousIsUpper && currentIsUpper && nextIsLower;
}

bool _isLowercaseLetter(String char) => RegExp(r'[a-z]').hasMatch(char);

bool _isUppercaseLetter(String char) => RegExp(r'[A-Z]').hasMatch(char);

String? _normalizeOrdinal(String value) {
  final match = RegExp(
    r'^(\d+)(st|nd|rd|th)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  final number = int.tryParse(match.group(1)!);
  if (number == null || number <= 0) {
    return null;
  }
  return _ordinalWord(number);
}

String? _ordinalWord(int number) {
  const ordinals = <int, String>{
    1: 'first',
    2: 'second',
    3: 'third',
    4: 'fourth',
    5: 'fifth',
    6: 'sixth',
    7: 'seventh',
    8: 'eighth',
    9: 'ninth',
    10: 'tenth',
    11: 'eleventh',
    12: 'twelfth',
    13: 'thirteenth',
    14: 'fourteenth',
    15: 'fifteenth',
    16: 'sixteenth',
    17: 'seventeenth',
    18: 'eighteenth',
    19: 'nineteenth',
    20: 'twentieth',
  };

  if (ordinals.containsKey(number)) {
    return ordinals[number];
  }

  const tens = <int, String>{
    20: 'twenty',
    30: 'thirty',
    40: 'forty',
    50: 'fifty',
    60: 'sixty',
    70: 'seventy',
    80: 'eighty',
    90: 'ninety',
  };

  if (tens.containsKey(number)) {
    return '${tens[number]}ieth'.replaceFirst('yie', 'ie');
  }

  if (number < 100) {
    final baseTens = (number ~/ 10) * 10;
    final remainder = number % 10;
    final tensWord = tens[baseTens];
    final ordinalRemainder = ordinals[remainder];
    if (tensWord != null && ordinalRemainder != null) {
      return '$tensWord-$ordinalRemainder';
    }
  }

  return null;
}

List<String> _buildInflectionFallbacks(String value) {
  final lower = value.toLowerCase();
  final variants = <String>[];

  void add(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty || trimmed == value || variants.contains(trimmed)) {
      return;
    }
    variants.add(trimmed);
  }

  if (lower.length > 4 && lower.endsWith('ies')) {
    add('${value.substring(0, value.length - 3)}y');
  }

  if (lower.length > 3 && lower.endsWith('es')) {
    add(value.substring(0, value.length - 2));
    add('${value.substring(0, value.length - 2)}e');
  }

  if (lower.length > 3 && lower.endsWith('s') && !lower.endsWith('ss')) {
    add(value.substring(0, value.length - 1));
  }

  if (lower.length > 4 && lower.endsWith('ed')) {
    add(value.substring(0, value.length - 2));
    add('${value.substring(0, value.length - 2)}e');
    add(value.substring(0, value.length - 1));
  }

  if (lower.length > 5 && lower.endsWith('ing')) {
    add(value.substring(0, value.length - 3));
    add('${value.substring(0, value.length - 3)}e');
  }

  return variants;
}
