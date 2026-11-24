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
        version: 2,
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
          await db.execute('CREATE INDEX idx_tasks_due_at ON tasks(due_at)');
          await db.execute("""
            CREATE TABLE projects (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              due_at TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          """);
          await db.execute('ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL');
          await db.execute('CREATE INDEX idx_tasks_project_id ON tasks(project_id)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
          await db.execute("""
            CREATE TABLE projects (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              due_at TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          """);
          await db.execute('ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL');
          await db.execute('CREATE INDEX idx_tasks_project_id ON tasks(project_id)');
          }
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
    int? projectId,
  }) async {
    final db = await database;
    return db.insert('tasks', {
      'title': title,
      'subject': subject,
      'due_at': due.toIso8601String(),
      'is_done': 0,
      'project_id': projectId,
    });
  }

  Future<int> updateTask({
    required int id,
    required String title,
    required String subject,
    required DateTime due,
    int? projectId,
  }) async {
    final db = await database;
    return db.update(
      'tasks',
      {'title': title, 'subject': subject, 'due_at': due.toIso8601String(), 'project_id': projectId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> getProjects() async {
    final db = await database;
    return db.query('projects', orderBy: 'due_at ASC, id DESC');
  }
  Future<int> insertProject({required String name, required String description, required DateTime due}) async {
    final db = await database;
    return db.insert('projects', {'name': name, 'description': description, 'due_at': due.toIso8601String(), 'created_at': DateTime.now().toIso8601String()});
  }
  Future<int> updateProject({required int id, required String name, required String description, required DateTime due}) async {
    final db = await database;
    return db.update('projects', {'name': name, 'description': description, 'due_at': due.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deleteProject(int id) async {
    final db = await database;
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
  Future<Map<String, Object?>> exportData() async {
    final db = await database;
    return {'format': 'nudge-backup', 'version': 1, 'exported_at': DateTime.now().toIso8601String(), 'projects': await db.query('projects', orderBy: 'id ASC'), 'tasks': await db.query('tasks', orderBy: 'id ASC')};
  }
  Future<void> importData(Map<String, dynamic> backup) async {
    if (backup['format'] != 'nudge-backup' || backup['version'] != 1 || backup['projects'] is! List || backup['tasks'] is! List) throw const FormatException('Invalid Nudge backup format.');
    final projects = (backup['projects'] as List).cast<Map<String, dynamic>>();
    final tasks = (backup['tasks'] as List).cast<Map<String, dynamic>>();
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks'); await txn.delete('projects');
      for (final p in projects) { await txn.insert('projects', {'id': p['id'], 'name': p['name'], 'description': p['description'] ?? '', 'due_at': p['due_at'], 'created_at': p['created_at'] ?? DateTime.now().toIso8601String()}); }
      for (final t in tasks) { await txn.insert('tasks', {'id': t['id'], 'title': t['title'], 'subject': t['subject'], 'due_at': t['due_at'], 'is_done': t['is_done'] ?? 0, 'project_id': t['project_id']}); }
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
