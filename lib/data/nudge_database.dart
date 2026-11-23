import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class NudgeDatabase {
  NudgeDatabase._();
  static final NudgeDatabase instance = NudgeDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'nudge.db'),
      version: 1,
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
    );
    return _database!;
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
