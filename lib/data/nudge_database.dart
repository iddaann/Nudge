import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'sqlite_platform.dart' as sqlitePlatform;

class NudgeDatabase {
  NudgeDatabase._({this._databasePathOverride});

  /// Creates an isolated database instance for tests.
  NudgeDatabase.forTesting({required String databasePath})
      : this._(databasePathOverride: databasePath);

  static final NudgeDatabase instance = NudgeDatabase._();
  final String? _databasePathOverride;
  Future<Database>? _databaseFuture;

  Future<Database> get database {
    final existing = _databaseFuture;
    if (existing != null) return existing;

    final opening = _openDatabase();
    _databaseFuture = opening;
    return opening.catchError((Object error) {
      if (identical(_databaseFuture, opening)) {
        _databaseFuture = null;
      }
      throw error;
    });
  }

  Future<Database> _openDatabase() async {
    await sqlitePlatform.initializeSqlitePlatform();
    final dbPath = _databasePathOverride ??
        p.join(await sqlitePlatform.getDatabaseDirectoryPath(), 'nudge.db');

    return sqlitePlatform.getDatabaseFactory().openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              subject TEXT NOT NULL,
              due_at TEXT NOT NULL,
              is_done INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_tasks_due_at ON tasks(due_at)',
          );
        },
      ),
    );
  }

  /// Closes this instance and clears its cached opening future.
  Future<void> close() async {
    final current = _databaseFuture;
    if (current == null) return;
    _databaseFuture = null;
    await current.then((db) => db.close());
  }

  Future<List<Map<String, Object?>>> getTasks() async {
    final db = await database;
    return db.query('tasks', orderBy: 'due_at ASC, id DESC');
  }

  Future<int> insertTask({
    required String title,
    required String subject,
    required DateTime due,
  }) async {
    final db = await database;
    return db.insert('tasks', {
      'title': title,
      'subject': subject,
      'due_at': due.toIso8601String(),
      'is_done': 0,
    });
  }

  Future<int> updateTaskDone(int id, bool isDone) async {
    final db = await database;
    return db.update(
      'tasks',
      {'is_done': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
