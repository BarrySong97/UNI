import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/tables/annotation-notes-table.dart';
import 'package:uni/services/db/tables/annotations-table.dart';

void main() {
  test(
    'v19 migration stays idempotent when annotation notes schema already exists',
    () async {
      final executor = _ExistingAnnotationNotesExecutor(
        legacyRows: <Map<String, Object?>>[
          <String, Object?>{
            AnnotationsTable.id: 'annotation-1',
            AnnotationsTable.bookId: 'book-1',
            AnnotationsTable.note: 'legacy note',
            AnnotationsTable.updatedAt: 123,
          },
        ],
      );

      await AppDatabase.migrateToV19ForTest(executor);

      expect(
        executor.executedSql,
        contains(
          startsWith(
            'CREATE TABLE IF NOT EXISTS ${AnnotationNotesTable.tableName}',
          ),
        ),
      );
      expect(
        executor.executedSql,
        contains(
          contains(
            'CREATE INDEX IF NOT EXISTS idx_annotation_notes_annotation_created',
          ),
        ),
      );
      expect(
        executor.executedSql,
        contains(
          contains(
            'CREATE INDEX IF NOT EXISTS idx_annotation_notes_book_created',
          ),
        ),
      );
      expect(executor.insertedRows, hasLength(1));
      expect(
        executor.insertedRows.single,
        containsPair(AnnotationNotesTable.id, 'annotation-1_note_legacy'),
      );
      expect(
        executor.insertedRows.single,
        containsPair(AnnotationNotesTable.text, 'legacy note'),
      );
      expect(executor.insertConflictAlgorithms, <ConflictAlgorithm?>[
        ConflictAlgorithm.ignore,
      ]);
    },
  );
}

class _ExistingAnnotationNotesExecutor implements DatabaseExecutor {
  _ExistingAnnotationNotesExecutor({required this.legacyRows});

  final List<Map<String, Object?>> legacyRows;
  final List<String> executedSql = <String>[];
  final List<Map<String, Object?>> insertedRows = <Map<String, Object?>>[];
  final List<ConflictAlgorithm?> insertConflictAlgorithms =
      <ConflictAlgorithm?>[];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    executedSql.add(sql);
    final createsAnnotationNotesSchema =
        sql.contains(AnnotationNotesTable.tableName) &&
        sql.startsWith('CREATE ');
    if (createsAnnotationNotesSchema && !sql.contains('IF NOT EXISTS')) {
      throw StateError('annotation notes migration must be idempotent');
    }
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    insertedRows.add(values);
    insertConflictAlgorithms.add(conflictAlgorithm);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return legacyRows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
