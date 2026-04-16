import 'dart:convert';

class ExplainHistoryEntity {
  const ExplainHistoryEntity({
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.selectedText,
    required this.contextSentence,
    required this.response,
    required this.createdAt,
  });

  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String selectedText;
  final String contextSentence;
  final String response;
  final DateTime createdAt;

  ExplainStructuredData? get structuredData =>
      ExplainStructuredData.tryParse(response);

  String get previewMeaning {
    final structured = structuredData;
    if (structured != null) {
      return structured.meaningExplain;
    }
    return response.trim();
  }
}

class ExplainStructuredData {
  const ExplainStructuredData({
    required this.meaningExplain,
    required this.detailExplain,
    required this.partOfSpeech,
  });

  final String meaningExplain;
  final List<String> detailExplain;
  final String partOfSpeech;

  static ExplainStructuredData? tryParse(String raw) {
    final jsonText = _extractJson(raw);
    if (jsonText == null) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;
      final meaningExplain = _readString(decoded['meaningExplain']).isNotEmpty
          ? _readString(decoded['meaningExplain'])
          : _readString(decoded['inThisSentence']);
      if (meaningExplain.isEmpty) return null;

      var detailExplain = _readStringList(decoded['detailExplain']);
      if (detailExplain.isEmpty) {
        final legacyWhy = _readStringList(decoded['whyThisMeaning']);
        final legacyNotHere = _readString(decoded['notHere']);
        final legacyAlternatives = _readStringList(
          decoded['nearbyAlternatives'],
        );
        detailExplain = [
          ...legacyWhy,
          if (legacyNotHere.isNotEmpty) 'Not here: $legacyNotHere',
          ...legacyAlternatives.map((item) => 'Alternative: $item'),
        ];
      }

      final partOfSpeech = _readString(decoded['partOfSpeech']).isNotEmpty
          ? _readString(decoded['partOfSpeech'])
          : _readString(decoded['pos']);

      return ExplainStructuredData(
        meaningExplain: meaningExplain,
        detailExplain: detailExplain,
        partOfSpeech: partOfSpeech,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(trimmed);
    if (fenced == null) return null;
    return fenced.group(1)?.trim();
  }

  static String _readString(Object? value) {
    if (value is String) return value.trim();
    return '';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map(_readString)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
