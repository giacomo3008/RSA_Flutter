import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openExecutor() async {
  final dir = await getApplicationSupportDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'rsa_demo.sqlite')),
  );
}
