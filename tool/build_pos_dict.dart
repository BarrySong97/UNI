// Build script for assets/dict/pos_dict.sqlite
//
// Downloads Princeton WordNet 3.1, parses lemma + POS information, and writes
// a single-table SQLite asset used by [PosService] for offline part-of-speech
// lookups in the reader.
//
// Run with:
//   dart run tool/build_pos_dict.dart
//
// The downloaded tarball is cached under .cache/wordnet/ so re-runs are fast.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

const _wordnetUrl = 'https://wordnetcode.princeton.edu/wn3.1.dict.tar.gz';
const _cacheDir = '.cache/wordnet';
const _tarballName = 'wn3.1.dict.tar.gz';
const _outputPath = 'assets/dict/pos_dict.sqlite';

// WordNet exposes four index files, each with a single POS character.
const _indexFiles = <String, String>{
  'dict/index.noun': 'n',
  'dict/index.verb': 'v',
  'dict/index.adj': 'a',
  'dict/index.adv': 'r',
};

// Exception files cover irregular inflections (ran -> run, oxen -> ox, ...).
const _excFiles = <String, String>{
  'dict/noun.exc': 'n',
  'dict/verb.exc': 'v',
  'dict/adj.exc': 'a',
  'dict/adv.exc': 'r',
};

// Stable display order so merged POS strings are deterministic.
const _posOrder = <String>['n', 'v', 'a', 'r'];

Future<void> main() async {
  final tarball = await _ensureTarball();
  final entries = _readTarball(tarball);

  final wordToPos = <String, Set<String>>{};

  for (final entry in _indexFiles.entries) {
    final bytes = entries[entry.key];
    if (bytes == null) {
      throw StateError('Missing ${entry.key} in WordNet archive');
    }
    _parseIndexFile(bytes, entry.value, wordToPos);
  }

  for (final entry in _excFiles.entries) {
    final bytes = entries[entry.key];
    if (bytes == null) {
      stderr.writeln('warning: ${entry.key} not found, skipping');
      continue;
    }
    _parseExceptionFile(bytes, entry.value, wordToPos);
  }

  final outputFile = File(_outputPath);
  await outputFile.parent.create(recursive: true);
  if (await outputFile.exists()) {
    await outputFile.delete();
  }

  final db = sqlite3.open(outputFile.path);
  try {
    db.execute('PRAGMA page_size = 4096');
    db.execute('PRAGMA journal_mode = OFF');
    db.execute('''
      CREATE TABLE pos_dict (
        word TEXT PRIMARY KEY,
        pos  TEXT NOT NULL
      ) WITHOUT ROWID
    ''');

    final insert = db.prepare('INSERT INTO pos_dict (word, pos) VALUES (?, ?)');
    db.execute('BEGIN');
    var rowCount = 0;
    final sortedWords = wordToPos.keys.toList()..sort();
    for (final word in sortedWords) {
      final posSet = wordToPos[word]!;
      final pos = _posOrder.where(posSet.contains).join();
      if (pos.isEmpty) continue;
      insert.execute([word, pos]);
      rowCount++;
    }
    db.execute('COMMIT');
    insert.dispose();

    db.execute('VACUUM');

    final size = await outputFile.length();
    stdout.writeln('Wrote $rowCount rows to ${outputFile.path}');
    stdout.writeln('SQLite file size: ${(size / 1024).toStringAsFixed(1)} KB');
  } finally {
    db.dispose();
  }
}

Future<File> _ensureTarball() async {
  final cacheDir = Directory(_cacheDir);
  await cacheDir.create(recursive: true);
  final file = File('${cacheDir.path}/$_tarballName');
  if (await file.exists() && (await file.length()) > 1024) {
    stdout.writeln('Using cached tarball at ${file.path}');
    return file;
  }
  stdout.writeln('Downloading $_wordnetUrl ...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(_wordnetUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('GET $_wordnetUrl returned ${response.statusCode}');
    }
    final sink = file.openWrite();
    await response.pipe(sink);
  } finally {
    client.close();
  }
  stdout.writeln('Saved to ${file.path}');
  return file;
}

Map<String, List<int>> _readTarball(File tarball) {
  final compressed = tarball.readAsBytesSync();
  final decompressed = GZipDecoder().decodeBytes(compressed);
  final archive = TarDecoder().decodeBytes(decompressed);
  final result = <String, List<int>>{};
  for (final file in archive) {
    if (!file.isFile) continue;
    result[file.name] = file.content as List<int>;
  }
  return result;
}

void _parseIndexFile(
  List<int> bytes,
  String pos,
  Map<String, Set<String>> wordToPos,
) {
  final text = String.fromCharCodes(bytes);
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith(' ')) continue;
    // Header lines in WordNet index files start with two leading spaces, but
    // we trimmed them above. License lines start with a digit followed by
    // space, while real data lines start with a lowercase lemma. Rely on the
    // structural cue that real entries have at least 6 whitespace-separated
    // columns.
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 6) continue;
    final lemma = parts[0];
    if (lemma.isEmpty) continue;
    if (lemma.contains('_')) continue; // skip multi-word entries
    if (!_isPlainAscii(lemma)) continue;
    wordToPos.putIfAbsent(lemma.toLowerCase(), () => <String>{}).add(pos);
  }
}

void _parseExceptionFile(
  List<int> bytes,
  String pos,
  Map<String, Set<String>> wordToPos,
) {
  final text = String.fromCharCodes(bytes);
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.isEmpty) continue;
    final inflected = parts[0];
    if (inflected.isEmpty) continue;
    if (inflected.contains('_')) continue;
    if (!_isPlainAscii(inflected)) continue;
    wordToPos
        .putIfAbsent(inflected.toLowerCase(), () => <String>{})
        .add(pos);
  }
}

bool _isPlainAscii(String value) {
  for (final unit in value.codeUnits) {
    if (unit < 0x20 || unit > 0x7e) return false;
  }
  return true;
}
