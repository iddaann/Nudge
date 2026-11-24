import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initializeSqlitePlatform() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

DatabaseFactory getDatabaseFactory() => databaseFactory;

Future<String> getDatabaseDirectoryPath() async {
  if (Platform.isWindows || Platform.isLinux) {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'Nudge', 'databases'),
    );
    await databaseDirectory.create(recursive: true);
    return databaseDirectory.path;
  }

  return getDatabasesPath();
}
