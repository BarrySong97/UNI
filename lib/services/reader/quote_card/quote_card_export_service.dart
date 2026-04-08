import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QuoteCardExportService {
  QuoteCardExportService({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    Future<void> Function(String path)? shareFile,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
       _shareFile = shareFile ?? _defaultShareFile;

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _tempDirectoryProvider;
  final Future<void> Function(String path) _shareFile;

  String buildFileName({required String bookTitle, DateTime? now}) {
    final timestamp = _formatTimestamp(now ?? DateTime.now());
    final normalized = bookTitle
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safeTitle = normalized.isEmpty ? 'book' : normalized;
    return 'quote-card-$safeTitle-$timestamp.png';
  }

  Future<String> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    _validateBytes(bytes);
    final documentsDirectory = await _documentsDirectoryProvider();
    final targetDirectory = Directory(
      p.join(documentsDirectory.path, 'exports', 'quote_cards'),
    );
    await targetDirectory.create(recursive: true);

    final file = File(p.join(targetDirectory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> sharePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    _validateBytes(bytes);
    final tempDirectory = await _tempDirectoryProvider();
    final file = File(p.join(tempDirectory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await _shareFile(file.path);
  }

  void _validateBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'PNG bytes cannot be empty.');
    }
  }
}

String _formatTimestamp(DateTime value) {
  final yyyy = value.year.toString().padLeft(4, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  final ss = value.second.toString().padLeft(2, '0');
  return '$yyyy$mm$dd-$hh$min$ss';
}

Future<void> _defaultShareFile(String path) async {
  await Share.shareXFiles(<XFile>[XFile(path)]);
}
