import 'package:drift/drift.dart';
import 'database_native.dart'
    if (dart.library.js_interop) 'database_web.dart'
    as platform;

/// Small custom-SQL Drift store; no generated row types leak into the domain.
class RsaDatabase extends GeneratedDatabase {
  RsaDatabase(super.executor);
  static Future<RsaDatabase> open() async =>
      RsaDatabase(await platform.openExecutor());
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement(
        'CREATE TABLE IF NOT EXISTS snapshot (id INTEGER PRIMARY KEY CHECK (id=1), body TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE IF NOT EXISTS event_keys (idempotency_key TEXT PRIMARY KEY, event_id TEXT NOT NULL UNIQUE)',
      );
      await customStatement(
        'CREATE TABLE IF NOT EXISTS event_claims (event_id TEXT PRIMARY KEY, staff_id TEXT NOT NULL, claimed_at TEXT NOT NULL)',
      );
    },
  );
}
