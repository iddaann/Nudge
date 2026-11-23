import 'package:flutter/material.dart';

void main() => runApp(const NudgeApp());

const bg = Color(0xFF17181B), panel = Color(0xFF242426), orange = Color(0xFFFF743A), muted = Color(0xFF96969B);

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nudge', debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg, colorScheme: const ColorScheme.dark(primary: orange, surface: panel), useMaterial3: true),
    home: const NudgeHome(),
  );
}

class Task {
  Task(this.title, this.course, this.deadline, {this.done = false});
  final String title, course;
  final DateTime deadline;
  bool done;
}

class NudgeHome extends StatefulWidget {
  const NudgeHome({super.key});
  @override
  State<NudgeHome> createState() => _NudgeHomeState();
}

class _NudgeHomeState extends State<NudgeHome> {
  int page = 0;
  final tasks = <Task>[
    Task('Review operating systems notes', 'Sistem Operasi', DateTime.now().add(const Duration(hours: 3))),
    Task('Finish database ERD', 'Basis Data', DateTime.now().add(const Duration(days: 1))),
    Task('Read chapter 4 — algorithms', 'Algoritma', DateTime.now().add(const Duration(days: 3))),
  ];
  int get done => tasks.where((t) => t.done).length;
  int get pending => tasks.length - done;

  void add(Task task) => setState(() => tasks.insert(0, task));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: page, children: [
      dashboard(),
      overview(),
      projects(),
      settings(),
    ])),
    floatingActionButton: page == 0 ? FloatingActionButton(backgroundColor: orange, foregroundColor: Colors.white, onPressed: () => addTask(context, add), child: const Icon(Icons.add, size: 30)) : null,
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: NavigationBar(
      backgroundColor: const Color(0xFF101011), indicatorColor: orange.withValues(alpha: .16),
      selectedIndex: page, onDestinationSelected: (i) => setState(() => page = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Overview'),
        NavigationDestination(icon: Icon(Icons.folder_open_outlined), label: 'Projects'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    ),
  );

  Widget dashboard() {
    final today = DateTime.now();
    final todayTasks = tasks.where((t) => !t.done && t.deadline.year == today.year && t.deadline.month == today.month && t.deadline.day == today.day).toList();
    final next = tasks.where((t) => !t.done).firstOrNull;
    return ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 100), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Icon(Icons.grid_view_rounded, color: Colors.white70), CircleAvatar(backgroundColor: Color(0xFF3C302B), child: Icon(Icons.person_outline, color: orange))]),
      const SizedBox(height: 28),
      const Text('Hello, Idan', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w300)),
      const SizedBox(height: 6),
      Text(pending.toString() + ' tasks are pending', style: const TextStyle(color: muted, fontSize: 14)),
      const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF38241B), Color(0xFF1E1E1F)])), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('UP NEXT', style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.4)),
          const SizedBox(height: 9),
          Text(next?.title ?? 'You’re all caught up', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(todayTasks.isNotEmpty ? 'Due today · ' + todayTasks.first.course : 'Keep your momentum going', style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        const Icon(Icons.arrow_forward_rounded, color: orange),
      ])),
      const SizedBox(height: 26),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Your progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)), Text(done.toString() + '/' + tasks.length.toString(), style: const TextStyle(color: muted))]),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: tasks.isEmpty ? 0 : done / tasks.length, minHeight: 7, backgroundColor: panel, color: orange)),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: stat(done.toString(), 'Done', Icons.check_circle_outline)), const SizedBox(width: 12), Expanded(child: stat(pending.toString(), 'To do', Icons.pending_outlined))]),
      const SizedBox(height: 26),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Task list', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)), TextButton(onPressed: () {}, child: const Text('See all', style: TextStyle(color: orange))]),
      if (tasks.isEmpty) const Padding(padding: EdgeInsets.only(top: 20), child: Text('No tasks yet. Tap + to add one.', style: TextStyle(color: muted))),
      ...tasks.take(6).map((t) => taskTile(t)),
    ]);
  }

  Widget stat(String value, String label, IconData icon) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(icon, color: orange, size: 21), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 24)), Text(label, style: const TextStyle(color: muted, fontSize: 12))])]));

  Widget taskTile(Task task) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17)), child: Row(children: [
    InkWell(onTap: () => setState(() => task.done = !task.done), child: Icon(task.done ? Icons.check_circle : Icons.circle_outlined, color: task.done ? orange : muted, size: 22)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(task.title, style: TextStyle(fontSize: 14, decoration: task.done ? TextDecoration.lineThrough : null, color: task.done ? muted : Colors.white)),
      const SizedBox(height: 4), Text(task.course + ' · ' + task.deadline.day.toString() + '/' + task.deadline.month.toString(), style: const TextStyle(color: muted, fontSize: 11)),
    ])),
  ]));

  Widget overview() => Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20), const Text('Overview', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w300)), const SizedBox(height: 8), const Text('A quick look at your workload.', style: TextStyle(color: muted)), const SizedBox(height: 24),
    stat(done.toString(), 'Completed tasks', Icons.task_alt), const SizedBox(height: 12), stat(pending.toString(), 'Still pending', Icons.hourglass_empty), const SizedBox(height: 24),
    const Text('Completion'), const SizedBox(height: 12), LinearProgressIndicator(value: tasks.isEmpty ? 0 : done / tasks.length, color: orange, backgroundColor: panel, minHeight: 7),
    const SizedBox(height: 8), Text(tasks.isEmpty ? 'No tasks yet' : (done / tasks.length * 100).round().toString() + '% completed', style: const TextStyle(color: muted)),
  ]));

  Widget projects() => Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 20), const Text('Projects', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w300)), const SizedBox(height: 8), const Text('Break bigger assignments into milestones.', style: TextStyle(color: muted)), const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.construction_outlined, color: orange, size: 28), SizedBox(height: 14), Text('Project workspace is next', style: TextStyle(fontSize: 17)), SizedBox(height: 6), Text('UAS projects will be split into steps, milestones, and deadlines to make the workload easier to manage.', style: TextStyle(color: muted, height: 1.5))]))]));

  Widget settings() => const Padding(padding: EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(height: 20), Text('Settings', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w300)), SizedBox(height: 8), Text('Personalize how Nudge works.', style: TextStyle(color: muted)),
    SizedBox(height: 20), ListTile(leading: Icon(Icons.notifications_outlined, color: orange), title: Text('Reminders'), subtitle: Text('Local notifications — planned next')),
    ListTile(leading: Icon(Icons.palette_outlined, color: orange), title: Text('Appearance'), subtitle: Text('Dark theme')),
    ListTile(leading: Icon(Icons.backup_outlined, color: orange), title: Text('Backup'), subtitle: Text('Local backup — planned')),
  ]));
}

Future<void> addTask(BuildContext context, void Function(Task) onSave) async {
  final title = TextEditingController(), course = TextEditingController();
  DateTime date = DateTime.now().add(const Duration(days: 1));
  await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: panel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => Padding(
    padding: EdgeInsets.fromLTRB(22, 24, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Add a task', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)), const SizedBox(height: 16),
      TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task name', hintText: 'e.g. Finish UAS report')),
      const SizedBox(height: 10), TextField(controller: course, decoration: const InputDecoration(labelText: 'Course / subject')),
      const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today_outlined, color: orange), title: const Text('Deadline'), subtitle: Text(date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString()), trailing: const Icon(Icons.chevron_right), onTap: () async {
        final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2035));
        if (picked != null) refresh(() => date = picked);
      }),
      const SizedBox(height: 10), SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), onPressed: () {
        if (title.text.trim().isEmpty) return;
        onSave(Task(title.text.trim(), course.text.trim().isEmpty ? 'Personal' : course.text.trim(), date)); Navigator.pop(ctx);
      }, child: const Text('Save task'))),
    ]),
  )));
}
