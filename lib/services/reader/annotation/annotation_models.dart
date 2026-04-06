import 'dart:convert';

import '../selection/page_hit_test.dart';

class AnnotationJumpTarget {
  const AnnotationJumpTarget({
    required this.chapterIndex,
    required this.chapterHref,
    required this.blockIndex,
    required this.offset,
  });

  final int chapterIndex;
  final String chapterHref;
  final int blockIndex;
  final int offset;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'chapterIndex': chapterIndex,
      'chapterHref': chapterHref,
      'blockIndex': blockIndex,
      'offset': offset,
    };
  }

  factory AnnotationJumpTarget.fromJson(Map<String, dynamic> json) {
    return AnnotationJumpTarget(
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterHref: json['chapterHref'] as String? ?? '',
      blockIndex: json['blockIndex'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
    );
  }
}

class AnnotationAnchorSegment {
  const AnnotationAnchorSegment({
    required this.chapterIndex,
    required this.chapterHref,
    required this.blockIndex,
    required this.startOffset,
    required this.endOffset,
    required this.quoteText,
    required this.prefixText,
    required this.suffixText,
    required this.blockTextHash,
  });

  final int chapterIndex;
  final String chapterHref;
  final int blockIndex;
  final int startOffset;
  final int endOffset;
  final String quoteText;
  final String prefixText;
  final String suffixText;
  final String blockTextHash;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'chapterIndex': chapterIndex,
      'chapterHref': chapterHref,
      'blockIndex': blockIndex,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'quoteText': quoteText,
      'prefixText': prefixText,
      'suffixText': suffixText,
      'blockTextHash': blockTextHash,
    };
  }

  factory AnnotationAnchorSegment.fromJson(Map<String, dynamic> json) {
    return AnnotationAnchorSegment(
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterHref: json['chapterHref'] as String? ?? '',
      blockIndex: json['blockIndex'] as int? ?? 0,
      startOffset: json['startOffset'] as int? ?? 0,
      endOffset: json['endOffset'] as int? ?? 0,
      quoteText: json['quoteText'] as String? ?? '',
      prefixText: json['prefixText'] as String? ?? '',
      suffixText: json['suffixText'] as String? ?? '',
      blockTextHash: json['blockTextHash'] as String? ?? '',
    );
  }
}

class AnnotationAnchorV1 {
  const AnnotationAnchorV1({
    required this.parserVersion,
    required this.segments,
    required this.jumpTarget,
  }) : version = 1;

  final int version;
  final int parserVersion;
  final List<AnnotationAnchorSegment> segments;
  final AnnotationJumpTarget jumpTarget;

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'parserVersion': parserVersion,
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'jumpTarget': jumpTarget.toJson(),
    };
  }

  static AnnotationAnchorV1? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AnnotationAnchorV1.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  factory AnnotationAnchorV1.fromJson(Map<String, dynamic> json) {
    return AnnotationAnchorV1(
      parserVersion: json['parserVersion'] as int? ?? 1,
      segments:
          (json['segments'] as List?)
              ?.map(
                (item) => AnnotationAnchorSegment.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false) ??
          const <AnnotationAnchorSegment>[],
      jumpTarget: AnnotationJumpTarget.fromJson(
        json['jumpTarget'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class ResolvedAnnotationSegment {
  const ResolvedAnnotationSegment({
    required this.annotationId,
    required this.chapterIndex,
    required this.pageIndexInChapter,
    required this.pageSelection,
    required this.color,
  });

  final String annotationId;
  final int chapterIndex;
  final int pageIndexInChapter;
  final PageSelection pageSelection;
  final String color;
}
