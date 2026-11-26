import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:nudge/data/nudge_database.dart';

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

  test('updates title, subject, and deadline', () async {
    final initialDue = DateTime(2026, 12, 10, 9);
    final id = await database.insertTask(
      title: 'Draft report',
      subject: 'Course A',
      due: initialDue,
    );
    final updatedDue = DateTime(2026, 12, 20, 15);
    final changed = await database.updateTask(
      id: id,
      title: 'Submit report',
      subject: 'Course B',
      due: updatedDue,
    );
    expect(changed, 1);
    final row = (await database.getTasks()).single;
    expect(row['title'], 'Submit report');
    expect(row['subject'], 'Course B');
    expect(row['due_at'], updatedDue.toIso8601String());
  });

  test('creates projects and preserves existing tasks during schema upgrade', () async {
    final taskId = await database.insertTask(title: 'Existing task', subject: 'Math', due: DateTime(2026, 12, 12));
    final projectId = await database.insertProject(name: 'Final project', description: 'Semester project', due: DateTime(2027, 1, 10));
    expect((await database.getProjects()).single['id'], projectId);
    expect((await database.getTasks()).single['id'], taskId);
  });

  test('exports and imports projects and tasks as one backup', () async {
    final projectId = await database.insertProject(name: 'Portfolio', description: 'Build portfolio', due: DateTime(2027, 1, 5));
    await database.insertTask(title: 'Build homepage', subject: 'Web', due: DateTime(2026, 12, 15), projectId: projectId);
    final backup = await database.exportData();
    await database.importData(backup);
    expect((await database.getProjects()).single['name'], 'Portfolio');
    final task = (await database.getTasks()).single;
    expect(task['title'], 'Build homepage');
    expect(task['project_id'], projectId);
  });

  test('rejects an invalid backup without deleting current data', () async {
    await database.insertTask(title: 'Keep me', subject: 'Test', due: DateTime(2026, 12, 20));
    await expectLater(database.importData({'format': 'wrong'}), throwsFormatException);
    expect((await database.getTasks()).single['title'], 'Keep me');
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
  test('rejects blank task fields and invalid project references', () async {
    await expectLater(
      database.insertTask(title: '  ', subject: 'Programming', due: DateTime(2026, 12, 10)),
      throwsArgumentError,
    );
    await expectLater(
      database.insertTask(title: 'Task', subject: 'Programming', due: DateTime(2026, 12, 10), projectId: 999),
      throwsArgumentError,
    );
    expect(await database.getTasks(), isEmpty);
  });

  test('malformed backup is rejected before existing data is replaced', () async {
    await database.insertTask(title: 'Keep existing', subject: 'Test', due: DateTime(2026, 12, 20));
    final invalid = {
      'format': 'nudge-backup',
      "version": 1,
      "projects": [],
      "tasks": [
        {"id": 1, "title": "Broken", "subject": "Test", "due_at": "not-a-date", "is_done": 0, "project_id": null}
      ]
    };
    await expectLater(database.importData(invalid), throwsFormatException);
    expect((await database.getTasks()).single['title'], 'Keep existing');
  });

  test('deleting a project unassigns its tasks instead of deleting them', () async {
    final projectId = await database.insertProject(name: 'Group project', description: '', due: DateTime(2027, 1, 10));
    await database.insertTask(title: 'Presentation', subject: 'OS', due: DateTime(2026, 12, 15), projectId: projectId);
    expect(await database.deleteProject(projectId), 1);
    final task = (await database.getTasks()).single;
    expect(task['title'], 'Presentation');
    expect(task['project_id'], isNull);
  });

  test('project CRUD and duplicate backup IDs are handled safely', () async {
    final projectId = await database.insertProject(name: 'Initial', description: 'd', due: DateTime(2027, 1, 10));
    expect(await database.updateProject(id: projectId, name: 'Updated', description: 'new', due: DateTime(2027, 2, 1)), 1);
    expect((await database.getProjects()).single['name'], 'Updated');
    await database.insertTask(title: 'Existing', subject: 'Test', due: DateTime(2026, 12, 20));
    final invalidBackup = {
      'format': 'nudge-backup',
      'version': 1,
      'projects': [
        {'id': 4, 'name': 'Duplicate A', 'description': '', 'due_at': '2027-01-01', 'created_at': '2026-11-26'},
        {'id': 4, 'name': 'Duplicate B', 'description': '', 'due_at': '2027-01-02', 'created_at': '2026-11-26'}
      ],
      'tasks': []
    };
    await expectLater(database.importData(invalidBackup), throwsFormatException);
    expect((await database.getTasks()).single['title'], 'Existing');
    expect((await database.getProjects()).single['name'], 'Updated');
    expect(await database.deleteProject(projectId), 1);
    expect(await database.getProjects(), isEmpty);
  });

}
