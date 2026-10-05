import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

Future<QueryExecutor> createDbExecutor({
  required Future<String> Function() keyProvider,
}) async {
  debugPrint(
    'WARNING: Running on web — database is NOT encrypted.',
  );

  final result = await WasmDatabase.open(
    databaseName: 'jolinx.pos.db',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
  );

  return result.resolvedExecutor;
}
