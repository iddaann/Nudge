import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../lib/data/nudge_database.dart';

void main() {
  late Directory temporaryDirectory;
  late NudgeDatabase database;

  setUpAll(() {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('nudge_db_test_');
    database = NudgeDatabase.forTesting(
      databasePath: p.join(temporaryDirectory.path, 'nudge_test.db'),
    );
  });

  tearDown(() async {
    await database.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('creates, toggles, and deletes tasks', () async {
    final due = DateTime(2026, 12, 10, 9);
    final id = await database.insertTask(
      title: 'Review OS notes',
      subject: 'Operating Systems',
      due: due,
    );

    var tasks = await database.getTasks();
    expect(tasks, hasLength(1));
    expect(tasks.single['id'], id);
    expect(tasks.single['title'], 'Review OS notes');
    expect(tasks.single['subject'], 'Operating Systems');
    expect(tasks.single['is_done'], 0);

    final updated = await database.updateTaskDone(id, true);
    expect(updated, 1);
    tasks = await database.getTasks();
    expect(tasks.single['is_done'], 1);

    final deleted = await database.deleteTask(id);
    expect(deleted, 1);
    expect(await database.getTasks(), isEmpty);
  });

  test('keeps task data after closing and reopening database', () async {
    final due = DateTime(2026, 12, 18, 13, 30);
    final id = await database.insertTask(
      title: 'Finish ERD',
      subject: 'Database',
      due: due,
    );
    await database.updateTaskDone(id, true);
    await database.close();

    final rows = await database.getTasks();
    expect(rows, hasLength(1));
    expect(rows.single['title'], 'Finish ERD');
    expect(rows.single['is_done'], 1);
    expect(rows.single['due_at'], due.toIso8601String());
  });
}
