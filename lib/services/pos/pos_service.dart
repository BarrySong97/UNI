export 'pos_models.dart';

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../phonetics/phonetics_candidate_builder.dart';
import 'pos_models.dart';

/// Looks up a normalized lowercase token in the bundled `pos_dict.sqlite`
/// asset and returns the compact POS code (e.g. `n`, `nv`) or `null`.
typedef PosLookupQuery = Future<String?> Function(String word);

/// Offline part-of-speech service backed by a Princeton WordNet snapshot.
///
/// At runtime the bundled `assets/dict/pos_dict.sqlite` is copied to the
/// app's databases directory on first launch and opened read-only. Tests
/// can bypass the asset/sqflite path entirely by supplying [queryOverride].
class PosService {
  PosService({
    PosLookupQuery? queryOverride,
    String? databasePathOverride,
  }) : _queryOverride = queryOverride,
       _databasePathOverride = databasePathOverride;

  static const String _assetPath = 'assets/dict/pos_dict.sqlite';
  static const String _databaseFilename = 'pos_dict.sqlite';

  final PosLookupQuery? _queryOverride;
  final String? _databasePathOverride;

  Database? _db;
  PosLookupQuery? _query;
  bool _initialized = false;

  bool get isReady => _initialized && _query != null;

  Future<void> initialize() async {
    if (_initialized) return;

    if (_queryOverride != null) {
      _query = _queryOverride;
      _initialized = true;
      return;
    }

    try {
      final path = await _resolveDatabasePath();
      await _ensureDatabaseFile(path);
      _db = await openReadOnlyDatabase(path);
      _query = _databaseLookup;
    } catch (_) {
      // POS is a "nice-to-have" enrichment; if asset copy or DB open fails
      // (e.g. on web or unsupported platforms), we degrade silently and the
      // service simply returns null on every lookup.
      _query = (_) async => null;
    }

    _initialized = true;
  }

  Future<PosResult?> lookup(String text) async {
    if (!_initialized) return null;
    final query = _query;
    if (query == null) return null;

    for (final candidate in buildPhoneticsFallbackCandidates(text)) {
      final code = await query(candidate.toLowerCase());
      if (code != null && code.isNotEmpty) {
        return PosResult(code: code, label: formatPosLabel(code));
      }
    }
    return null;
  }

  Future<void> dispose() async {
    final db = _db;
    _db = null;
    _query = null;
    _initialized = false;
    if (db != null) {
      await db.close();
    }
  }

  Future<String> _resolveDatabasePath() async {
    final override = _databasePathOverride;
    if (override != null) return override;
    final root = await getDatabasesPath();
    return p.join(root, _databaseFilename);
  }

  Future<void> _ensureDatabaseFile(String path) async {
    final file = File(path);
    if (await file.exists() && await file.length() > 0) return;
    final data = await rootBundle.load(_assetPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  Future<String?> _databaseLookup(String word) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.rawQuery(
      'SELECT pos FROM pos_dict WHERE word = ? LIMIT 1',
      [word],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['pos'];
    return value is String ? value : null;
  }
}
