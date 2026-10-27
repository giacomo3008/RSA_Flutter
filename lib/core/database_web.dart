import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

Future<QueryExecutor> openExecutor() async {
  final result = await WasmDatabase.open(
    databaseName: 'rsa_demo',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
  );
  if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
    throw StateError(
      'Persistent browser storage is unavailable. Enable site storage and reload.',
    );
  }
  return result.resolvedExecutor;
}
