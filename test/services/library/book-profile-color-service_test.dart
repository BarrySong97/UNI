import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/library/book-profile-color-service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns default gradient when cover is null', () async {
    final service = BookProfileColorService();

    final result = await service.resolveTopGradient(null);
    final fallback = service.defaultTopGradient();

    expect(result.colors.first.toARGB32(), fallback.colors.first.toARGB32());
    expect(result.colors.last.toARGB32(), fallback.colors.last.toARGB32());
  });

  test('extracts color-based gradient for valid cover bytes', () async {
    final service = BookProfileColorService(
      dominantColorExtractor: (bytes) async => const Color(0xFFCC3344),
    );
    final fallback = service.defaultTopGradient();
    final coverBytes = Uint8List.fromList(<int>[10, 20, 30, 40]);

    final result = await service.resolveTopGradient(coverBytes);

    final differsFromFallback =
        result.colors.first.toARGB32() != fallback.colors.first.toARGB32() ||
        result.colors.last.toARGB32() != fallback.colors.last.toARGB32();
    expect(differsFromFallback, isTrue);
  });

  test('resolves profile background color hex from cover bytes', () async {
    final service = BookProfileColorService(
      dominantColorExtractor: (bytes) async => const Color(0xFF336699),
    );

    final result = await service.resolveProfileBgColorHex(
      Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(result, startsWith('#FF'));
    expect(result, hasLength(9));
  });

  test('builds gradient from stored hex color', () {
    final service = BookProfileColorService();
    final fallback = service.defaultTopGradient();

    final gradient = service.gradientFromStoredHex('#FFCC3344');

    expect(
      gradient.colors.first.toARGB32(),
      isNot(fallback.colors.first.toARGB32()),
    );
  });

  test('falls back safely for invalid cover bytes', () async {
    final service = BookProfileColorService();
    final invalid = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]);
    final fallback = service.defaultTopGradient();

    final result = await service.resolveTopGradient(invalid);

    expect(result.colors.first.toARGB32(), fallback.colors.first.toARGB32());
    expect(result.colors.last.toARGB32(), fallback.colors.last.toARGB32());
  });
}
