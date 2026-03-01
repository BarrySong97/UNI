import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class BookProfileColorService {
  const BookProfileColorService({this.dominantColorExtractor});

  final Future<Color?> Function(Uint8List bytes)? dominantColorExtractor;

  LinearGradient defaultTopGradient() {
    final base = LibraryDesignTokens.bookProfileTopBgBase;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        base.withValues(
          alpha: LibraryDesignTokens.bookProfileTopGradientOpacityStart,
        ),
        base.withValues(
          alpha: LibraryDesignTokens.bookProfileTopGradientOpacityEnd,
        ),
      ],
    );
  }

  Future<LinearGradient> resolveTopGradient(Uint8List? coverBytes) async {
    final tunedColor = await _resolveTunedColor(coverBytes);
    if (tunedColor == null) {
      return defaultTopGradient();
    }
    return _buildGradientForColor(tunedColor);
  }

  Future<String?> resolveProfileBgColorHex(Uint8List? coverBytes) async {
    final tunedColor = await _resolveTunedColor(coverBytes);
    if (tunedColor == null) {
      return null;
    }
    return _toArgbHex(tunedColor);
  }

  LinearGradient gradientFromStoredHex(String? profileBgColorHex) {
    final color = _parseArgbHex(profileBgColorHex);
    if (color == null) {
      return defaultTopGradient();
    }
    return _buildGradientForColor(color);
  }

  Future<Color?> _resolveTunedColor(Uint8List? coverBytes) async {
    if (coverBytes == null || coverBytes.isEmpty) {
      return null;
    }
    try {
      final extractor = dominantColorExtractor ?? _extractDominantColor;
      final dominantColor = await extractor(coverBytes);
      if (dominantColor == null) {
        return null;
      }
      return _tuneForBackground(dominantColor);
    } catch (_) {
      return null;
    }
  }

  String _toArgbHex(Color color) {
    final value = color.toARGB32();
    final hex = value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#$hex';
  }

  Color? _parseArgbHex(String? hex) {
    if (hex == null) {
      return null;
    }
    final normalized = hex.trim();
    if (!RegExp(r'^#[0-9A-Fa-f]{8}$').hasMatch(normalized)) {
      return null;
    }
    final value = int.tryParse(normalized.substring(1), radix: 16);
    if (value == null) {
      return null;
    }
    return Color(value);
  }

  LinearGradient _buildGradientForColor(Color color) {
    final base = LibraryDesignTokens.bookProfileTopBgBase;
    final transition = Color.alphaBlend(color.withValues(alpha: 0.35), base);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        color.withValues(
          alpha: LibraryDesignTokens.bookProfileTopGradientOpacityStart,
        ),
        transition.withValues(alpha: 0.28),
        base.withValues(
          alpha: LibraryDesignTokens.bookProfileTopGradientOpacityEnd,
        ),
      ],
      stops: const <double>[0.0, 0.55, 1.0],
    );
  }

  Future<Color?> _extractDominantColor(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 32,
      targetHeight: 32,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData == null) {
          return null;
        }
        final rgba = byteData.buffer.asUint8List();
        var red = 0;
        var green = 0;
        var blue = 0;
        var samples = 0;
        final width = image.width;
        final height = image.height;
        final startX = width ~/ 4;
        final endX = (width * 3) ~/ 4;
        final startY = height ~/ 4;
        final endY = (height * 3) ~/ 4;

        for (var y = startY; y < endY; y += 2) {
          for (var x = startX; x < endX; x += 2) {
            final offset = (y * width + x) * 4;
            red += rgba[offset];
            green += rgba[offset + 1];
            blue += rgba[offset + 2];
            samples++;
          }
        }

        if (samples == 0) {
          return null;
        }
        return Color.fromARGB(
          255,
          red ~/ samples,
          green ~/ samples,
          blue ~/ samples,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Color _tuneForBackground(Color color) {
    final hsl = HSLColor.fromColor(color);
    final saturation = hsl.saturation.clamp(0.35, 0.82);
    final lightness = hsl.lightness.clamp(0.40, 0.72);
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }
}
