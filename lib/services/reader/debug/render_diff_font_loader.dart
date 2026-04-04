import 'dart:io';

import 'package:flutter/services.dart';

class RenderDiffFontLoader {
  const RenderDiffFontLoader._();

  static final Set<String> _loadedFamilies = <String>{};

  static Future<void> ensureLoaded(String? family) async {
    final targetFamily = family?.trim();
    if (targetFamily == null || targetFamily.isEmpty) {
      return;
    }
    if (_loadedFamilies.contains(targetFamily)) {
      return;
    }

    final fontFiles = _resolveFontFiles(targetFamily);
    if (fontFiles.isEmpty) {
      return;
    }

    final loader = FontLoader(targetFamily);
    for (final file in fontFiles) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future<ByteData>.value(_toByteData(bytes)));
    }
    await loader.load();
    _loadedFamilies.add(targetFamily);
  }

  static List<File> _resolveFontFiles(String family) {
    if (!Platform.isMacOS) {
      return const <File>[];
    }

    return switch (family.toLowerCase()) {
      'georgia' => _existingFiles(const <String>[
          '/System/Library/Fonts/Supplemental/Georgia.ttf',
          '/System/Library/Fonts/Supplemental/Georgia Bold.ttf',
          '/System/Library/Fonts/Supplemental/Georgia Italic.ttf',
          '/System/Library/Fonts/Supplemental/Georgia Bold Italic.ttf',
        ]),
      'times' || 'times new roman' => _existingFiles(const <String>[
          '/System/Library/Fonts/Times.ttc',
          '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
          '/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf',
          '/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf',
          '/System/Library/Fonts/Supplemental/Times New Roman Bold Italic.ttf',
        ]),
      _ => const <File>[],
    };
  }

  static List<File> _existingFiles(List<String> paths) {
    return paths.map(File.new).where((file) => file.existsSync()).toList();
  }

  static ByteData _toByteData(Uint8List bytes) {
    return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
  }
}
