import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> initializeSqlitePlatform() async {
  databaseFactory = databaseFactoryFfiWeb;
}

DatabaseFactory getDatabaseFactory() => databaseFactoryFfiWeb;

/// On web the database path is an IndexedDB name, not a filesystem directory.
Future<String> getDatabaseDirectoryPath() async => '';
