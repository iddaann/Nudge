import 'package:sqflite/sqflite.dart';

Future<void> initializeSqlitePlatform() async {
  throw UnsupportedError(
    'SQLite persistence in Nudge is not configured for web yet. '
    'Run Nudge on Android, iOS, Windows, Linux, or macOS.',
  );
}

DatabaseFactory getDatabaseFactory() => databaseFactory;

Future<String> getDatabaseDirectoryPath() => getDatabasesPath();
