/// Result of a part-of-speech lookup against the bundled WordNet asset.
///
/// [code] is the compact lowercase string from `pos_dict` (e.g. `n`, `nv`,
/// `nvar`); [label] is a human-readable form for UI display
/// (e.g. `noun, verb`).
class PosResult {
  const PosResult({required this.code, required this.label});

  final String code;
  final String label;

  bool get isEmpty => code.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() => 'PosResult(code: $code, label: $label)';
}

/// Returns a display label like "noun" or "noun, verb" for a compact POS
/// code such as `n` or `nv`. Unknown characters are dropped silently.
String formatPosLabel(String code) {
  if (code.isEmpty) return '';
  final labels = <String>[];
  for (final char in code.split('')) {
    final label = _posCharToLabel[char];
    if (label != null && !labels.contains(label)) {
      labels.add(label);
    }
  }
  return labels.join(', ');
}

const _posCharToLabel = <String, String>{
  'n': 'noun',
  'v': 'verb',
  'a': 'adjective',
  'r': 'adverb',
};
