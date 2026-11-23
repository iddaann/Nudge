import 'package:flutter/material.dart';

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
  Task({required this.title, required this.subject, required this.due, this.done = false});
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
  final List<Task> _tasks = [
    Task(title: 'Review operating systems notes', subject: 'Sistem Operasi', due: DateTime.now().add(const Duration(hours: 4))),
    Task(title: 'Finish database ERD', subject: 'Basis Data', due: DateTime.now().add(const Duration(days: 1))),
    Task(title: 'Read chapter 4 — algorithms', subject: 'Algoritma', due: DateTime.now().add(const Duration(days: 3))),
  ];
  int get _completed => _tasks.where((t) => t.done).length;
  int get _pending => _tasks.length - _completed;

  void _addTask(Task task) => setState(() => _tasks.insert(0, task));
  void _toggle(Task task) => setState(() => task.done = !task.done);
  void _remove(Task task) => setState(() => _tasks.remove(task));

  @override
  Widget build(BuildContext context) {
    final screens = [_home(), _overview(), _projects(), _settings()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: screens)),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddTask(),
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
        ..._tasks.take(6).map(_taskTile),
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
    onDismissed: (_) => _remove(task),
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
        const Icon(Icons.more_horiz, color: _muted, size: 19),
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

  Future<void> _showAddTask() async {
    final title = TextEditingController();
    final subject = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(days: 1));
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, refresh) => Padding(
        padding: EdgeInsets.fromLTRB(22, 24, 22, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add a task', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task name', hintText: 'e.g. Finish UAS report')),
          const SizedBox(height: 10),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Course / subject', hintText: 'e.g. Sistem Operasi')),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined, color: _orange), title: const Text('Deadline'), subtitle: Text(_dateLabel(deadline)), trailing: const Icon(Icons.chevron_right, color: _muted), onTap: () async {
            final picked = await showDatePicker(context: sheetContext, initialDate: deadline, firstDate: DateTime.now(), lastDate: DateTime(2035), builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: _orange, surface: _surface)), child: child!));
            if (picked != null) refresh(() => deadline = picked);
          }),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) return;
            _addTask(Task(title: title.text.trim(), subject: subject.text.trim().isEmpty ? 'Personal' : subject.text.trim(), due: deadline));
            Navigator.pop(sheetContext);
          }, style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text('Save task'))),
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
