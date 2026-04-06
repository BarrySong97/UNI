import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class NormalizedTextMapping {
  NormalizedTextMapping._({
    required this.normalizedText,
    required this.rawBoundaryToNormalized,
    required this.normalizedBoundaryToRaw,
  });

  final String normalizedText;
  final List<int> rawBoundaryToNormalized;
  final List<int> normalizedBoundaryToRaw;

  factory NormalizedTextMapping.fromRaw(String rawText) {
    final buffer = StringBuffer();
    final rawBoundaryToNormalized = List<int>.filled(rawText.length + 1, 0);
    final normalizedBoundaryToRaw = <int>[0];
    var pendingSpace = false;
    var hasOutput = false;

    for (var i = 0; i < rawText.length; i++) {
      final char = rawText[i];
      if (_isWhitespace(char)) {
        if (hasOutput) {
          pendingSpace = true;
        }
        rawBoundaryToNormalized[i + 1] = buffer.length;
        continue;
      }

      if (pendingSpace && buffer.isNotEmpty) {
        buffer.write(' ');
        normalizedBoundaryToRaw.add(i);
      }

      buffer.write(char);
      normalizedBoundaryToRaw.add(i + 1);
      rawBoundaryToNormalized[i + 1] = buffer.length;
      pendingSpace = false;
      hasOutput = true;
    }

    for (var i = 1; i < rawBoundaryToNormalized.length; i++) {
      if (rawBoundaryToNormalized[i] < rawBoundaryToNormalized[i - 1]) {
        rawBoundaryToNormalized[i] = rawBoundaryToNormalized[i - 1];
      }
    }

    while (normalizedBoundaryToRaw.length < buffer.length + 1) {
      normalizedBoundaryToRaw.add(rawText.length);
    }

    return NormalizedTextMapping._(
      normalizedText: buffer.toString(),
      rawBoundaryToNormalized: rawBoundaryToNormalized,
      normalizedBoundaryToRaw: normalizedBoundaryToRaw,
    );
  }

  int rawToNormalizedBoundary(int rawOffset) {
    final clamped = rawOffset.clamp(0, rawBoundaryToNormalized.length - 1);
    return rawBoundaryToNormalized[clamped];
  }

  int normalizedToRawBoundary(int normalizedOffset) {
    final clamped = normalizedOffset.clamp(
      0,
      normalizedBoundaryToRaw.length - 1,
    );
    return normalizedBoundaryToRaw[clamped];
  }
}

String normalizeAnnotationText(String text) {
  final mapping = NormalizedTextMapping.fromRaw(text);
  return mapping.normalizedText.trim();
}

String hashNormalizedText(String text) {
  final normalized = normalizeAnnotationText(text);
  return sha1.convert(normalized.codeUnits).toString();
}

Color annotationColorFromHex(String raw, {double alpha = 0.35}) {
  final hex = raw.trim().replaceAll('#', '');
  if (hex.length != 6) {
    return const Color(0x59FFE082);
  }
  final value = int.tryParse(hex, radix: 16);
  if (value == null) {
    return const Color(0x59FFE082);
  }
  final color = Color(0xFF000000 | value);
  return color.withValues(alpha: alpha);
}

String truncateNormalizedPrefix(String text, int maxChars) {
  final normalized = normalizeAnnotationText(text);
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return normalized.substring(normalized.length - maxChars);
}

String truncateNormalizedSuffix(String text, int maxChars) {
  final normalized = normalizeAnnotationText(text);
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return normalized.substring(0, maxChars);
}

bool _isWhitespace(String char) => RegExp(r'\s').hasMatch(char);
