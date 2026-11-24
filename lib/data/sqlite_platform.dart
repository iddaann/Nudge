import 'package:sqflite/sqflite.dart';

import 'sqlite_platform_stub.dart'
    if (dart.library.io) 'sqlite_platform_io.dart'
    if (dart.library.js_interop) 'sqlite_platform_web.dart' as platform;

Future<void> initializeSqlitePlatform() => platform.initializeSqlitePlatform();

DatabaseFactory getDatabaseFactory() => platform.getDatabaseFactory();

Future<String> getDatabaseDirectoryPath() =>
    platform.getDatabaseDirectoryPath();
