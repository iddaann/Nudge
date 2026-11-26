import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/nudge_database.dart';
import 'services/reminder_service.dart';

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
  Task({this.id, required this.title, required this.subject, required this.due, this.done = false, this.projectId});
  final int? id;
  final String title;
  final String subject;
  final DateTime due;
  bool done;
  final int? projectId;
}

class StudyProject {
  StudyProject({required this.id, required this.name, required this.description, required this.due});
  final int id;
  final String name;
  final String description;
  final DateTime due;
}

class NudgeHome extends StatefulWidget {
  const NudgeHome({super.key});
  @override
  State<NudgeHome> createState() => _NudgeHomeState();
}

class _NudgeHomeState extends State<NudgeHome> {
  int _tab = 0;
  String _taskFilter = 'All';
  String _searchQuery = '';
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDay = DateTime.now();
  final List<StudyProject> _projectsList = [];
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
        projectId: row['project_id'] as int?,
      )).toList();
      try { await ReminderService.instance.rescheduleAll(rows); } catch (reminderError) { debugPrint('Reminder setup skipped: $reminderError'); }
      final projectRows = await NudgeDatabase.instance.getProjects();
      final loadedProjects = projectRows.map((row) => StudyProject(id: row['id'] as int, name: row['name'] as String, description: row['description'] as String, due: DateTime.parse(row['due_at'] as String))).toList();
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(loaded);
        _projectsList..clear()..addAll(loadedProjects);
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
      projectId: task.projectId,
    );
    try { await ReminderService.instance.scheduleTask(taskId: id, title: task.title, due: task.due, done: false); } catch (error) { debugPrint('Reminder schedule failed: $error'); }
    if (!mounted) return;
    setState(() => _tasks.insert(0, Task(
      id: id,
      title: task.title,
      subject: task.subject,
      due: task.due,
      projectId: task.projectId,
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
    try {
      await ReminderService.instance.scheduleTask(taskId: id, title: task.title, due: task.due, done: nextDone);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status tersimpan, tetapi reminder gagal: $error')));
    }
  }

  Future<void> _remove(Task task) async {
    final index = _tasks.indexOf(task);
    if (index < 0) return;
    // Dismissible needs the widget removed synchronously after the swipe.
    setState(() => _tasks.removeAt(index));
    try {
      if (task.id != null) await NudgeDatabase.instance.deleteTask(task.id!);
    } catch (error) {
      if (!mounted) return;
      final restoreAt = index > _tasks.length ? _tasks.length : index;
      setState(() => _tasks.insert(restoreAt, task));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tugas gagal dihapus dari database: $error')));
      return;
    }
    if (task.id != null) {
      try { await ReminderService.instance.cancelTask(task.id!); } catch (error) { debugPrint('Reminder cancel failed: $error'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [_home(), _overview(), _calendar(), _projects(), _settings()];
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
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.folder_open_outlined), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  List<Task> _sortTasksByPriority(Iterable<Task> tasks) {
    final result = tasks.toList();
    result.sort((a, b) {
      // In the All view, unfinished tasks always stay above completed tasks.
      if (a.done != b.done) return a.done ? 1 : -1;
      // Oldest overdue task first; otherwise nearest deadline first.
      final dueOrder = a.due.compareTo(b.due);
      if (dueOrder != 0) return dueOrder;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return result;
  }

  List<Task> _filteredHomeTasks() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    Iterable<Task> filtered;
    switch (_taskFilter) {
      case 'Overdue':
        filtered = _tasks.where((t) => !t.done && t.due.isBefore(todayStart));
        break;
      case 'Today':
        filtered = _tasks.where((t) => !t.done && !t.due.isBefore(todayStart) && t.due.isBefore(tomorrowStart));
        break;
      case 'Upcoming':
        filtered = _tasks.where((t) => !t.done && !t.due.isBefore(tomorrowStart));
        break;
      case 'Completed':
        filtered = _tasks.where((t) => t.done);
        break;
      default:
        filtered = _tasks;
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) filtered = filtered.where((t) => t.title.toLowerCase().contains(query) || t.subject.toLowerCase().contains(query));
    return _sortTasksByPriority(filtered);
  }

  Widget _home() {
    final now = DateTime.now();
    final today = _tasks.where((t) => !t.done && _sameDay(t.due, now)).toList();
    final next = _sortTasksByPriority(_tasks.where((t) => !t.done));
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
        const SizedBox(height: 12),
        _smartNudge(),
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
        if (_tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(onChanged: (value) => setState(() => _searchQuery = value), decoration: InputDecoration(hintText: 'Search tasks or subjects', prefixIcon: const Icon(Icons.search, color: _muted), filled: true, fillColor: _surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 10)))),
        if (_tasks.isEmpty) _emptyTasks(),
        if (_tasks.isNotEmpty) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['All', 'Overdue', 'Today', 'Upcoming', 'Completed'].map((filter) {
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

  Widget _smartNudge() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final todayTasks = _tasks.where((t) => !t.done && !t.due.isBefore(start) && t.due.isBefore(end)).toList();
    final overdueTasks = _tasks.where((t) => !t.done && t.due.isBefore(start)).toList();
    final weekEnd = start.add(const Duration(days: 7));
    final dueSoon = _tasks.where((t) => !t.done && !t.due.isBefore(start) && t.due.isBefore(weekEnd)).toList();
    final crowded = dueSoon.any((task) => dueSoon.where((t) => _sameDay(t.due, task.due)).length >= 3);
    String headline, detail;
    IconData icon;
    Color accent;
    if (overdueTasks.isNotEmpty) {
      headline = 'Clear overdue tasks first';
      detail = '${overdueTasks.length} task(s) past deadline. Pick one and finish a small part today.';
      icon = Icons.warning_amber_rounded; accent = Colors.redAccent;
    } else if (todayTasks.length >= 3) {
      headline = 'Today is packed';
      detail = '${todayTasks.length} deadlines today. Prioritize one, then use focused work blocks.';
      icon = Icons.local_fire_department_outlined; accent = _orange;
    } else if (crowded) {
      headline = 'Deadline cluster detected';
      detail = 'At least one day this week has 3+ unfinished tasks. Start one early.';
      icon = Icons.calendar_month_outlined; accent = Colors.amber;
    } else if (todayTasks.isNotEmpty) {
      headline = 'One task to focus on today';
      detail = 'Finish ${_sortTasksByPriority(todayTasks).first.title} before taking on another.';
      icon = Icons.bolt_outlined; accent = _orange;
    } else if (dueSoon.isNotEmpty) {
      headline = 'Make a little progress';
      detail = '${dueSoon.length} upcoming tasks this week. Start with ${_sortTasksByPriority(dueSoon).first.title}.';
      icon = Icons.lightbulb_outline; accent = _orange;
    } else {
      headline = 'You have breathing room';
      detail = 'No deadlines in the next 7 days. Get ahead or add upcoming tasks.';
      icon = Icons.spa_outlined; accent = _orange;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withValues(alpha: .25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: accent, size: 22), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SMART NUDGE', style: TextStyle(color: accent, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5), Text(headline, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 5), Text(detail, style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
      ]),
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
        Text(task != null && !task.done && task.due.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) ? 'OVERDUE · UP NEXT' : 'UP NEXT', style: TextStyle(color: task != null && !task.done && task.due.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) ? Colors.redAccent : _muted, fontSize: 11, letterSpacing: 1.5)),
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
          Text('${task.subject} · ${_taskDeadlineLabel(task.due, task.done)}', style: TextStyle(color: _taskDeadlineColor(task.due, task.done), fontSize: 11)),
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
    final upcoming = _sortTasksByPriority(_tasks.where((t) => !t.done));
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final overdue = _tasks.where((t) => !t.done && t.due.isBefore(todayStart)).length;
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

  Widget _calendar() {
    final first = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final days = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final offset = first.weekday - 1;
    final selectedTasks = _sortTasksByPriority(_tasks.where((t) => _sameDay(t.due, _selectedCalendarDay)));
    return ListView(padding: const EdgeInsets.all(22), children: [
      const Text('Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
        Text('${_monthName(_calendarMonth.month)} ${_calendarMonth.year}', style: const TextStyle(fontSize: 18)),
        IconButton(onPressed: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text('M'), Text('T'), Text('W'), Text('T'), Text('F'), Text('S'), Text('S')]),
      const SizedBox(height: 10),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: offset + days, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6), itemBuilder: (context, index) {
        if (index < offset) return const SizedBox();
        final day = index - offset + 1;
        final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
        final hasTasks = _tasks.any((t) => _sameDay(t.due, date));
        final selected = _sameDay(date, _selectedCalendarDay);
        return InkWell(onTap: () => setState(() => _selectedCalendarDay = date), borderRadius: BorderRadius.circular(12), child: Container(decoration: BoxDecoration(color: selected ? _orange.withValues(alpha: .2) : _surface, borderRadius: BorderRadius.circular(12), border: selected ? Border.all(color: _orange) : null), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$day'), if (hasTasks) Container(width: 5, height: 5, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle))])));
      }),
      const SizedBox(height: 20),
      Text('Tasks · ${_selectedCalendarDay.day} ${_monthName(_selectedCalendarDay.month)}', style: const TextStyle(fontSize: 17)),
      const SizedBox(height: 10),
      if (selectedTasks.isEmpty) const Text('No tasks on this date.', style: TextStyle(color: _muted)) else ...selectedTasks.map(_taskTile),
    ]);
  }
  Future<void> _showProjectDialog({StudyProject? project}) async {
    final name = TextEditingController(text: project?.name ?? '');
    final description = TextEditingController(text: project?.description ?? '');
    DateTime due = project?.due ?? DateTime.now().add(const Duration(days: 30));
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(backgroundColor: _surface, title: Text(project == null ? 'New project' : 'Edit project'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name')),
      TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
      ListTile(title: const Text('Deadline'), subtitle: Text(_dateLabel(due)), onTap: () async { final picked = await showDatePicker(context: ctx, initialDate: due, firstDate: DateTime(2000), lastDate: DateTime(2035)); if (picked != null) refresh(() => due = picked); }),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(onPressed: () async {
        if (name.text.trim().isEmpty) return;
        if (project == null) {
          final id = await NudgeDatabase.instance.insertProject(name: name.text.trim(), description: description.text.trim(), due: due);
          if (mounted) setState(() => _projectsList.add(StudyProject(id: id, name: name.text.trim(), description: description.text.trim(), due: due)));
        } else {
          await NudgeDatabase.instance.updateProject(id: project.id, name: name.text.trim(), description: description.text.trim(), due: due);
          if (mounted) setState(() { final i = _projectsList.indexOf(project); if (i >= 0) _projectsList[i] = StudyProject(id: project.id, name: name.text.trim(), description: description.text.trim(), due: due); });
        }
        if (ctx.mounted) Navigator.pop(ctx);
      }, child: const Text('Save')),
    ])));
    name.dispose(); description.dispose();
  }

  Future<void> _deleteProject(StudyProject project) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: _surface, title: const Text('Delete project?'), content: const Text('Tasks assigned to it will remain and become unassigned.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
    if (ok != true) return;
    await NudgeDatabase.instance.deleteProject(project.id);
    if (mounted) setState(() => _projectsList.remove(project));
  }
  Widget _projects() => ListView(padding: const EdgeInsets.all(22), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Projects', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)), IconButton(onPressed: () => _showProjectDialog(), icon: const Icon(Icons.add, color: _orange))]),
    const Text('Group related tasks into projects and milestones.', style: TextStyle(color: _muted)),
    const SizedBox(height: 18),
    if (_projectsList.isEmpty) const Text('No projects yet. Create one to get started.', style: TextStyle(color: _muted)),
    ..._projectsList.map((project) {
      final items = _tasks.where((t) => t.projectId == project.id).toList();
      final completed = items.where((t) => t.done).length;
      final ratio = items.isEmpty ? 0.0 : completed / items.length;
      return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(project.name, style: const TextStyle(fontSize: 17))), PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _showProjectDialog(project: project); if (v == 'delete') _deleteProject(project); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))])]),
        if (project.description.isNotEmpty) Text(project.description, style: const TextStyle(color: _muted)),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: ratio, color: _orange, backgroundColor: _surface2),
        const SizedBox(height: 6),
        Text('$completed/${items.length} milestones completed · Due ${_dateLabel(project.due)}', style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 8),
        ...items.map(_taskTile),
        TextButton.icon(onPressed: () => _showAddTask(projectId: project.id), icon: const Icon(Icons.add), label: const Text('Add milestone', style: TextStyle(color: _orange))),
      ]));
    }),
  ]);
  Widget _settings() => ListView(padding: const EdgeInsets.fromLTRB(22, 24, 22, 30), children: [
    const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
    const SizedBox(height: 7),
    const Text('Keep Nudge simple and personal.', style: TextStyle(color: _muted)),
    const SizedBox(height: 20),
    ListTile(leading: const Icon(Icons.notifications_active_outlined, color: _orange), title: const Text('Deadline reminders'), subtitle: const Text('Reschedule reminders for unfinished tasks', style: TextStyle(color: _muted, fontSize: 12)), onTap: _refreshReminders),
    _settingTile(Icons.dark_mode_outlined, 'Appearance', 'Dark mode · warm orange accents'),
    ListTile(leading: const Icon(Icons.backup_outlined, color: _orange), title: const Text('Export backup'), subtitle: const Text('Copy JSON backup to clipboard', style: TextStyle(color: _muted, fontSize: 12)), onTap: _exportBackup),
    ListTile(leading: const Icon(Icons.restore_outlined, color: _orange), title: const Text('Import backup'), subtitle: const Text('Restore from JSON backup', style: TextStyle(color: _muted, fontSize: 12)), onTap: _importBackup),
    _settingTile(Icons.info_outline_rounded, 'About Nudge', 'Personal academic task tracker'),
  ]);

  Future<void> _refreshReminders() async {
    if (kIsWeb) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Browser tidak mendukung reminder terjadwal. Smart Nudge tetap tersedia.')));
      return;
    }
    try {
      await ReminderService.instance.rescheduleAll(await NudgeDatabase.instance.getTasks());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder schedules refreshed. Notification permission may be required.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not schedule reminders: $error')));
    }
  }

  Future<void> _exportBackup() async {
    final data = await NudgeDatabase.instance.exportData();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup JSON copied. Save it in a safe place.')));
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: _surface, title: const Text('Import backup'), content: SizedBox(width: 480, child: TextField(controller: controller, minLines: 5, maxLines: 10, decoration: const InputDecoration(hintText: 'Paste Nudge backup JSON'))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore'))]));
    if (confirmed == true) {
      try {
        final decoded = jsonDecode(controller.text) as Map<String, dynamic>;
        await NudgeDatabase.instance.importData(decoded);
        await _loadTasks();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully.')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup invalid: $error')));
      }
    }
    controller.dispose();
  }
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

  Future<void> _showAddTask({Task? task, int? projectId}) async {
    final title = TextEditingController(text: task?.title ?? '');
    final subject = TextEditingController(text: task?.subject ?? '');
    DateTime deadline = task?.due ?? DateTime.now().add(const Duration(days: 1));
    int? selectedProjectId = task?.projectId ?? projectId;
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
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(value: selectedProjectId, decoration: const InputDecoration(labelText: 'Project'), items: [const DropdownMenuItem<int?>(value: null, child: Text('No project')), ..._projectsList.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name)))], onChanged: (value) => refresh(() => selectedProjectId = value)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
            if (title.text.trim().isEmpty) return;
            try {
              final newTitle = title.text.trim();
              final newSubject = subject.text.trim().isEmpty ? 'Personal' : subject.text.trim();
              if (task == null) {
                await _addTask(Task(title: newTitle, subject: newSubject, due: deadline, projectId: selectedProjectId));
              } else {
                final id = task.id;
                if (id == null) throw StateError('Task has no database ID.');
                final changed = await NudgeDatabase.instance.updateTask(
                  id: id, title: newTitle, subject: newSubject, due: deadline, projectId: selectedProjectId,
                );
                if (changed == 0) throw StateError('Task no longer exists.');
                try { await ReminderService.instance.scheduleTask(taskId: id, title: newTitle, due: deadline, done: task.done); } catch (reminderError) { debugPrint('Reminder update failed: $reminderError'); }
                if (mounted) {
                  setState(() {
                    final index = _tasks.indexOf(task);
                    if (index >= 0) {
                      _tasks[index] = Task(id: id, title: newTitle, subject: newSubject, due: deadline, done: task.done, projectId: selectedProjectId);
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
  final dayStart = DateTime(now.year, now.month, now.day);
  if (date.isBefore(dayStart)) return 'Overdue · ${date.day} ${_monthName(date.month)}';
  return '${date.day} ${_monthName(date.month)}';
}
String _monthName(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

String _taskDeadlineLabel(DateTime due, bool done) {
  if (done) return _dateLabel(due);
  final now = DateTime.now();
  if (due.isBefore(DateTime(now.year, now.month, now.day))) {
    return 'Overdue · ${due.day} ${_monthName(due.month)}';
  }
  return _dateLabel(due);
}
Color _taskDeadlineColor(DateTime due, bool done) {
  if (!done) {
    final now = DateTime.now();
    if (due.isBefore(DateTime(now.year, now.month, now.day))) return Colors.redAccent;
  }
  return _muted;
}
