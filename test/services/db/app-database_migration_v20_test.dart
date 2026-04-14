import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/tables/phonetics-cache-table.dart';

void main() {
  test('v20 migration creates phonetics cache schema idempotently', () async {
    final executor = _MigrationExecutor();

    await AppDatabase.migrateToV20ForTest(executor);

    expect(
      executor.executedSql.single,
      contains('CREATE TABLE IF NOT EXISTS ${PhoneticsCacheTable.tableName}'),
    );
  });
}

class _MigrationExecutor implements DatabaseExecutor {
  final List<String> executedSql = <String>[];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    executedSql.add(sql);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
