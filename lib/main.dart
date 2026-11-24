import 'package:flutter/material.dart';
import 'data/nudge_database.dart';

void main() => runApp(const NudgeApp());

const _bg = Color(0xFF171719);
const _surface = Color(0xFF232325);
const _surface2 = Color(0xFF2B2B2D);
const _orange = Color(0xFFFF783F);
const _muted = Color(0xFF96969B);

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nudge',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(primary: _orange, surface: _surface),
      useMaterial3: true,
      fontFamily: 'Roboto',
    ),
    home: const NudgeHome(),
  );
}

class Task {
  Task({this.id, required this.title, required this.subject, required this.due, this.done = false});
  final int? id;
  final String title;
  final String subject;
  final DateTime due;
  bool done;
}

class NudgeHome extends StatefulWidget {
  const NudgeHome({super.key});
  @override
  State<NudgeHome> createState() => _NudgeHomeState();
}

class _NudgeHomeState extends State<NudgeHome> {
  int _tab = 0;
  String _taskFilter = 'All';
  final List<Task> _tasks = [];
  bool _isLoading = true;
  String? _loadError;
  final Set<int> _updatingTaskIds = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final rows = await NudgeDatabase.instance.getTasks();
      final loaded = rows.map((row) => Task(
        id: row['id'] as int,
        title: row['title'] as String,
        subject: row['subject'] as String,
        due: DateTime.parse(row['due_at'] as String),
        done: (row['is_done'] as int) == 1,
      )).toList();
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(loaded);
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _retryLoadTasks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    await _loadTasks();
  }

  Widget _databaseErrorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storage_outlined, color: _orange, size: 40),
          const SizedBox(height: 14),
          const Text(
            'Could not open local database',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _loadError ?? 'Unknown database error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _retryLoadTasks,
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  int get _completed => _tasks.where((t) => t.done).length;
  int get _pending => _tasks.length - _completed;

  Future<void> _addTask(Task task) async {
    final id = await NudgeDatabase.instance.insertTask(
      title: task.title,
      subject: task.subject,
      due: task.due,
    );
    if (!mounted) return;
    setState(() => _tasks.insert(0, Task(
      id: id,
      title: task.title,
      subject: task.subject,
      due: task.due,
    )));
  }

  Future<void> _toggle(Task task) async {
    final id = task.id;
    if (id == null || _updatingTaskIds.contains(id)) return;
    final previous = task.done;
    final nextDone = !previous;
    _updatingTaskIds.add(id);
    setState(() => task.done = nextDone);
    try {
      final changed = await NudgeDatabase.instance.updateTaskDone(id, nextDone);
      if (changed == 0) throw StateError('Task $id no longer exists in SQLite.');
    } catch (error) {
      if (!mounted) return;
      setState(() => task.done = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status gagal disimpan: $error')),
      );
    } finally {
      _updatingTaskIds.remove(id);
    }
  }

  Future<void> _remove(Task task) async {
    final index = _tasks.indexOf(task);
    if (index < 0) return;
    // Dismissible needs the widget removed synchronously after the swipe.
    setState(() => _tasks.removeAt(index));
    try {
      if (task.id != null) {
        await NudgeDatabase.instance.deleteTask(task.id!);
      }
    } catch (error) {
      if (!mounted) return;
      final restoreAt = index > _tasks.length ? _tasks.length : index;
      setState(() => _tasks.insert(restoreAt, task));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tugas gagal dihapus dari database: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [_home(), _overview(), _projects(), _settings()];
    return Scaffold(
      body: SafeArea(child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _loadError != null
              ? _databaseErrorView()
              : IndexedStack(index: _tab, children: screens)),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: (_isLoading || _loadError != null) ? null : () => _showAddTask(),
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              elevation: 1,
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF111112),
        indicatorColor: _orange.withValues(alpha: .13),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.folder_open_outlined), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  List<Task> _filteredHomeTasks() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    switch (_taskFilter) {
      case 'Today':
        return _tasks.where((t) => !t.done && t.due.isBefore(tomorrowStart) && !t.due.isBefore(todayStart)).toList();
      case 'Upcoming':
        return _tasks.where((t) => !t.done && !t.due.isBefore(tomorrowStart)).toList();
      case 'Completed':
        return _tasks.where((t) => t.done).toList();
      default:
        return List<Task>.from(_tasks);
    }
  }

  Widget _home() {
    final now = DateTime.now();
    final today = _tasks.where((t) => !t.done && _sameDay(t.due, now)).toList();
    final next = _tasks.where((t) => !t.done).toList()..sort((a, b) => a.due.compareTo(b.due));
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Icon(Icons.grid_view_rounded, color: Colors.white70),
          const CircleAvatar(radius: 20, backgroundColor: Color(0xFF3D2D25), child: Icon(Icons.person_outline, color: _orange, size: 20)),
        ]),
        const SizedBox(height: 28),
        const Text('Hello, Idan', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w300, letterSpacing: -.4)),
        const SizedBox(height: 6),
        Text('$_pending tasks waiting for you', style: const TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 22),
        _nextCard(next.isEmpty ? null : next.first, today),
        const SizedBox(height: 26),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Your progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Text('$_completed / ${_tasks.length}', style: const TextStyle(color: _muted)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _tasks.isEmpty ? 0 : _completed / _tasks.length, minHeight: 7, backgroundColor: _surface2, color: _orange)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _statCard('$_completed', 'Completed', Icons.check_circle_outline)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('$_pending', 'Remaining', Icons.timelapse_rounded)),
        ]),
        const SizedBox(height: 27),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          TextButton(onPressed: () => setState(() => _tab = 1), child: const Text('View overview', style: TextStyle(color: _orange))),
        ]),
        if (_tasks.isEmpty) _emptyTasks(),
        if (_tasks.isNotEmpty) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['All', 'Today', 'Upcoming', 'Completed'].map((filter) {
              final selected = _taskFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: selected,
                  onSelected: (_) => setState(() => _taskFilter = filter),
                  backgroundColor: _surface,
                  selectedColor: _orange.withValues(alpha: .18),
                  checkmarkColor: _orange,
                  side: BorderSide(color: selected ? _orange.withValues(alpha: .5) : _surface2),
                  labelStyle: TextStyle(color: selected ? _orange : Colors.white70, fontSize: 12),
                  showCheckmark: false,
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 12),
          if (_filteredHomeTasks().isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No tasks in this filter.', style: TextStyle(color: _muted)),
            )
          else
            ..._filteredHomeTasks().take(6).map(_taskTile),
        ],
      ],
    );
  }

  Widget _nextCard(Task? task, List<Task> today) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(23),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF40271D), Color(0xFF252323)]),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('UP NEXT', style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 1.5)),
        const SizedBox(height: 9),
        Text(task?.title ?? 'All caught up', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(task != null ? '${task.subject} · ${_dateLabel(task.due)}' : 'Take a breather. You earned it.', style: const TextStyle(color: _muted, fontSize: 12)),
      ])),
      const Icon(Icons.arrow_forward_rounded, color: _orange),
    ]),
  );

  Widget _statCard(String value, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 15),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      Icon(icon, color: _orange, size: 21), const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ]),
    ]),
  );

  Widget _taskTile(Task task) => Dismissible(
    key: ObjectKey(task),
    direction: DismissDirection.endToStart,
    background: Container(margin: const EdgeInsets.only(bottom: 10), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: .7), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.delete_outline)),
    onDismissed: (_) { _remove(task); },
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        InkWell(onTap: () => _toggle(task), borderRadius: BorderRadius.circular(20), child: Icon(task.done ? Icons.check_circle_rounded : Icons.circle_outlined, color: task.done ? _orange : _muted, size: 23)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, style: TextStyle(fontSize: 14, decoration: task.done ? TextDecoration.lineThrough : null, color: task.done ? _muted : Colors.white)),
          const SizedBox(height: 5),
          Text('${task.subject} · ${_dateLabel(task.due)}', style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: _muted, size: 19),
          color: _surface2,
          onSelected: (choice) {
            if (choice == 'edit') _showAddTask(task: task);
            if (choice == 'delete') _remove(task);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit task')),
            PopupMenuItem(value: 'delete', child: Text('Delete task')),
          ],
        ),
      ]),
    ),
  );

  Widget _overview() {
    final ratio = _tasks.isEmpty ? 0.0 : _completed / _tasks.length;
    final upcoming = _tasks.where((t) => !t.done).toList()..sort((a, b) => a.due.compareTo(b.due));
    final overdue = _tasks.where((t) => !t.done && t.due.isBefore(DateTime.now())).length;
    return ListView(padding: const EdgeInsets.fromLTRB(22, 24, 22, 30), children: [
      const Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
      const SizedBox(height: 7),
      const Text('A clear picture of your workload.', style: TextStyle(color: _muted)),
      const SizedBox(height: 24),
      _statCard('$_completed', 'Completed tasks', Icons.task_alt_outlined),
      const SizedBox(height: 12),
      _statCard('$_pending', 'Still pending', Icons.hourglass_empty_rounded),
      const SizedBox(height: 12),
      _statCard('$overdue', 'Overdue', Icons.warning_amber_rounded),
      const SizedBox(height: 25),
      const Text('Overall progress', style: TextStyle(fontSize: 17)),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: _surface2, color: _orange)),
      const SizedBox(height: 8),
      Text('${(ratio * 100).round()}% complete', style: const TextStyle(color: _muted)),
      const SizedBox(height: 28),
      const Text('Coming up', style: TextStyle(fontSize: 17)),
      const SizedBox(height: 12),
      ...upcoming.take(4).map(_taskTile),
    ]);
  }

  Widget _projects() => ListView(padding: const EdgeInsets.all(22), children: [
    const SizedBox(height: 8),
    const Text('Projects', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
    const SizedBox(height: 7),
    const Text('Make big assignments feel manageable.', style: TextStyle(color: _muted)),
    const SizedBox(height: 23),
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: _orange.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.layers_outlined, color: _orange)),
      const SizedBox(height: 16),
      const Text('UAS Project Planner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      const SizedBox(height: 7),
      const Text('Break a final project into milestones, small tasks, and realistic due dates. Project planning will be the next feature we build.', style: TextStyle(color: _muted, height: 1.5)),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: () => _showAddTask(), icon: const Icon(Icons.add), label: const Text('Add a project task'), style: OutlinedButton.styleFrom(foregroundColor: _orange)),
    ])),
    const SizedBox(height: 20),
    const Text('Tasks assigned to projects will be grouped here in a later update.', style: TextStyle(color: _muted, height: 1.5)),
  ]);

  Widget _settings() => ListView(padding: const EdgeInsets.fromLTRB(22, 24, 22, 30), children: [
    const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
    const SizedBox(height: 7),
    const Text('Keep Nudge simple and personal.', style: TextStyle(color: _muted)),
    const SizedBox(height: 20),
    _settingTile(Icons.notifications_none_rounded, 'Reminders', 'Scheduled local reminders will be added next'),
    _settingTile(Icons.dark_mode_outlined, 'Appearance', 'Dark mode · warm orange accents'),
    _settingTile(Icons.backup_outlined, 'Data backup', 'Local backup option planned'),
    _settingTile(Icons.info_outline_rounded, 'About Nudge', 'Personal academic task tracker'),
  ]);

  Widget _settingTile(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
    child: ListTile(leading: Icon(icon, color: _orange), title: Text(title), subtitle: Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12))),
  );

  Widget _emptyTasks() => Padding(padding: const EdgeInsets.symmetric(vertical: 25), child: Column(children: const [
    Icon(Icons.task_alt_outlined, size: 36, color: _muted), SizedBox(height: 10),
    Text('No tasks yet', style: TextStyle(color: _muted)), SizedBox(height: 4),
    Text('Tap + to add your first task.', style: TextStyle(color: _muted, fontSize: 12)),
  ]));

  Future<void> _showAddTask({Task? task}) async {
    final title = TextEditingController(text: task?.title ?? '');
    final subject = TextEditingController(text: task?.subject ?? '');
    DateTime deadline = task?.due ?? DateTime.now().add(const Duration(days: 1));
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(22, 24, 22, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task == null ? 'Add a task' : 'Edit task', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task name', hintText: 'e.g. Finish UAS report')),
          const SizedBox(height: 10),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Course / subject', hintText: 'e.g. Sistem Operasi')),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined, color: _orange), title: const Text('Deadline'), subtitle: Text(_dateLabel(deadline)), trailing: const Icon(Icons.chevron_right, color: _muted), onTap: () async {
            final picked = await showDatePicker(context: sheetContext, initialDate: deadline, firstDate: DateTime(2000), lastDate: DateTime(2035), builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: _orange, surface: _surface)), child: child!));
            if (picked != null) refresh(() => deadline = picked);
          }),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
            if (title.text.trim().isEmpty) return;
            try {
              final newTitle = title.text.trim();
              final newSubject = subject.text.trim().isEmpty ? 'Personal' : subject.text.trim();
              if (task == null) {
                await _addTask(Task(title: newTitle, subject: newSubject, due: deadline));
              } else {
                final id = task.id;
                if (id == null) throw StateError('Task has no database ID.');
                final changed = await NudgeDatabase.instance.updateTask(
                  id: id, title: newTitle, subject: newSubject, due: deadline,
                );
                if (changed == 0) throw StateError('Task no longer exists.');
                if (mounted) {
                  setState(() {
                    final index = _tasks.indexOf(task);
                    if (index >= 0) {
                      _tasks[index] = Task(id: id, title: newTitle, subject: newSubject, due: deadline, done: task.done);
                    }
                  });
                }
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } catch (error) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(content: Text('Tugas gagal disimpan: $error')),
              );
            }
          }, style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(task == null ? 'Save task' : 'Save changes'))),
        ]),
      )),
    );
    title.dispose();
    subject.dispose();
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dateLabel(DateTime date) {
  final now = DateTime.now();
  if (_sameDay(date, now)) return 'Today';
  if (_sameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
  return '${date.day} ${_monthName(date.month)}';
}
String _monthName(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
