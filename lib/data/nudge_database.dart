import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'sqlite_platform.dart' as sqlitePlatform;

class NudgeDatabase {
  NudgeDatabase._({this._databasePathOverride});
  NudgeDatabase.forTesting({required String databasePath}) : this._(databasePathOverride: databasePath);
  static final NudgeDatabase instance = NudgeDatabase._();
  final String? _databasePathOverride;
  Future<Database>? _databaseFuture;

  Future<Database> get database {
    final existing = _databaseFuture;
    if (existing != null) return existing;
    final opening = _openDatabase();
    _databaseFuture = opening;
    return opening.catchError((Object error) {
      if (identical(_databaseFuture, opening)) _databaseFuture = null;
      throw error;
    });
  }

  Future<Database> _openDatabase() async {
    await sqlitePlatform.initializeSqlitePlatform();
    final dbPath = _databasePathOverride ?? p.join(await sqlitePlatform.getDatabaseDirectoryPath(), 'nudge.db');
    return sqlitePlatform.getDatabaseFactory().openDatabase(dbPath, options: OpenDatabaseOptions(
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, subject TEXT NOT NULL, due_at TEXT NOT NULL, is_done INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE INDEX idx_tasks_due_at ON tasks(due_at)');
        await db.execute("""CREATE TABLE projects (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', due_at TEXT NOT NULL, created_at TEXT NOT NULL)""");
        await db.execute('ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL');
        await db.execute('CREATE INDEX idx_tasks_project_id ON tasks(project_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("""CREATE TABLE projects (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', due_at TEXT NOT NULL, created_at TEXT NOT NULL)""");
          await db.execute('ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL');
          await db.execute('CREATE INDEX idx_tasks_project_id ON tasks(project_id)');
        }
      },
    ));
  }

  String _requiredText(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) throw FormatException('$field must be a non-empty string.');
    return value.trim();
  }
  String _dateText(Object? value, String field) {
    if (value is! String) throw FormatException('$field must be an ISO date string.');
    try { DateTime.parse(value); } catch (_) { throw FormatException('$field is not a valid date.'); }
    return value;
  }
  int _backupId(Object? value, String field) {
    if (value is! int || value <= 0) throw FormatException('$field must be a positive integer.');
    return value;
  }
  Map<String, Object?> _validateProjectBackup(Object? raw) {
    if (raw is! Map) throw const FormatException('Each project must be an object.');
    final row = Map<String, Object?>.from(raw);
    return {
      'id': _backupId(row['id'], 'project.id'),
      'name': _requiredText(row['name'], 'project.name'),
      'description': row['description'] is String ? row['description'] : '',
      'due_at': _dateText(row['due_at'], 'project.due_at'),
      'created_at': row['created_at'] is String ? _dateText(row['created_at'], 'project.created_at') : DateTime.now().toIso8601String(),
    };
  }
  Map<String, Object?> _validateTaskBackup(Object? raw, Set<int> projectIds) {
    if (raw is! Map) throw const FormatException('Each task must be an object.');
    final row = Map<String, Object?>.from(raw);
    final id = _backupId(row['id'], 'task.id');
    final done = row['is_done'] ?? 0;
    if (done is! int || (done != 0 && done != 1)) throw FormatException('task $id is_done must be 0 or 1.');
    final projectId = row['project_id'];
    if (projectId != null && (projectId is! int || !projectIds.contains(projectId))) throw FormatException('task $id references an unknown project.');
    return {
      'id': id, 'title': _requiredText(row['title'], 'task.title'),
      'subject': _requiredText(row['subject'], 'task.subject'),
      'due_at': _dateText(row['due_at'], 'task.due_at'), 'is_done': done, 'project_id': projectId,
    };
  }
  Future<void> _requireProject(DatabaseExecutor db, int? projectId) async {
    if (projectId == null) return;
    final rows = await db.query('projects', columns: ['id'], where: 'id = ?', whereArgs: [projectId], limit: 1);
    if (rows.isEmpty) throw ArgumentError('Project $projectId does not exist.');
  }

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
  Future<int> insertTask({required String title, required String subject, required DateTime due, int? projectId}) async {
    final db = await database;
    final cleanTitle = _requiredText(title, 'task.title');
    final cleanSubject = _requiredText(subject, 'task.subject');
    await _requireProject(db, projectId);
    return db.insert('tasks', {'title': cleanTitle, 'subject': cleanSubject, 'due_at': due.toIso8601String(), 'is_done': 0, 'project_id': projectId});
  }
  Future<int> updateTask({required int id, required String title, required String subject, required DateTime due, int? projectId}) async {
    final db = await database;
    final cleanTitle = _requiredText(title, 'task.title');
    final cleanSubject = _requiredText(subject, 'task.subject');
    await _requireProject(db, projectId);
    return db.update('tasks', {'title': cleanTitle, 'subject': cleanSubject, 'due_at': due.toIso8601String(), 'project_id': projectId}, where: 'id = ?', whereArgs: [id]);
  }
  Future<List<Map<String, Object?>>> getProjects() async {
    final db = await database;
    return db.query('projects', orderBy: 'due_at ASC, id DESC');
  }
  Future<int> insertProject({required String name, required String description, required DateTime due}) async {
    final db = await database;
    return db.insert('projects', {'name': _requiredText(name, 'project.name'), 'description': description.trim(), 'due_at': due.toIso8601String(), 'created_at': DateTime.now().toIso8601String()});
  }
  Future<int> updateProject({required int id, required String name, required String description, required DateTime due}) async {
    final db = await database;
    return db.update('projects', {'name': _requiredText(name, 'project.name'), 'description': description.trim(), 'due_at': due.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deleteProject(int id) async {
    final db = await database;
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
  Future<Map<String, Object?>> exportData() async {
    final db = await database;
    return db.transaction((txn) async => {
      'format': 'nudge-backup', 'version': 1, 'exported_at': DateTime.now().toIso8601String(),
      'projects': await txn.query('projects', orderBy: 'id ASC'), 'tasks': await txn.query('tasks', orderBy: 'id ASC'),
    });
  }

  /// Validate all records before replacement, then restore in a single transaction.
  Future<void> importData(Map<String, dynamic> backup) async {
    if (backup['format'] != 'nudge-backup' || backup['version'] != 1 || backup['projects'] is! List || backup['tasks'] is! List) {
      throw const FormatException('Invalid Nudge backup format.');
    }
    final projects = (backup['projects'] as List).map(_validateProjectBackup).toList();
    final projectIds = projects.map((p) => p['id'] as int).toSet();
    if (projectIds.length != projects.length) throw const FormatException('Backup contains duplicate project IDs.');
    final tasks = (backup['tasks'] as List).map((t) => _validateTaskBackup(t, projectIds)).toList();
    final taskIds = tasks.map((t) => t['id'] as int).toSet();
    if (taskIds.length != tasks.length) throw const FormatException('Backup contains duplicate task IDs.');

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('projects');
      for (final project in projects) { await txn.insert('projects', project); }
      for (final task in tasks) { await txn.insert('tasks', task); }
    });
  }
  Future<int> updateTaskDone(int id, bool isDone) async {
    final db = await database;
    return db.update('tasks', {'is_done': isDone ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deleteTask(int id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
