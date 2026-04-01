class RenderDiffTextNormalizer {
  const RenderDiffTextNormalizer._();

  static String normalize(String text) {
    final replaced = text
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    return replaced.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String stableHash(String input) {
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
