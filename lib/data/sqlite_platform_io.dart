import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<void> initializeSqlitePlatform() async {
  if (Platform.isWindows || Platform.isLinux) {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfi;
  }
}

sqflite.DatabaseFactory getDatabaseFactory() => sqflite.databaseFactory;

Future<String> getDatabaseDirectoryPath() async {
  if (Platform.isWindows || Platform.isLinux) {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'Nudge', 'databases'),
    );
    await databaseDirectory.create(recursive: true);
    return databaseDirectory.path;
  }

  return sqflite.getDatabasesPath();
}
