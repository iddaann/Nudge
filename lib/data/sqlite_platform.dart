import 'package:sqflite/sqflite.dart';

import 'sqlite_platform_stub.dart'
    if (dart.library.io) 'sqlite_platform_io.dart' as platform;

Future<void> initializeSqlitePlatform() => platform.initializeSqlitePlatform();

DatabaseFactory getDatabaseFactory() => platform.getDatabaseFactory();

Future<String> getDatabaseDirectoryPath() =>
    platform.getDatabaseDirectoryPath();
