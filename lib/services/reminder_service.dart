import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Android local reminder engine. Web intentionally uses an in-app fallback.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    timezone_data.initializeTimeZones();
    // Nudge currently targets Indonesia; device timezone auto-detection is not
    // exposed by timezone itself, so make this explicit and document the limitation.
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  int _notificationId(int taskId, int stage) => taskId * 10 + stage;

  Future<void> cancelTask(int taskId) async {
    if (kIsWeb) return;
    await initialize();
    for (var stage = 1; stage <= 4; stage++) {
      await _plugin.cancel(_notificationId(taskId, stage));
    }
  }

  Future<void> scheduleTask({required int taskId, required String title, required DateTime due, required bool done}) async {
    if (kIsWeb) return;
    await initialize();
    await cancelTask(taskId);
    if (done) return;
    final now = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final dayBeforeAtNine = dueDay.subtract(const Duration(days: 1)).add(const Duration(hours: 9));
    final dueAtNine = dueDay.add(const Duration(hours: 9));
    final overdueAtNine = dueDay.add(const Duration(days: 1, hours: 9));
    final items = <({int stage, DateTime when, String message})>[
      (stage: 1, when: dayBeforeAtNine, message: 'Deadline $title besok. Mulai cicil sekarang.'),
      (stage: 2, when: dueAtNine, message: 'Deadline $title hari ini. Jangan sampai terlewat.'),
      (stage: 3, when: overdueAtNine, message: '$title belum selesai? Atur waktu untuk menyelesaikannya.'),
      (stage: 4, when: overdueAtNine.add(const Duration(days: 1)), message: '$title masih overdue. Prioritaskan atau ubah rencana.'),
    ];
    for (final item in items) {
      if (!item.when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        _notificationId(taskId, item.stage),
        item.stage <= 2 ? 'Deadline mendekat' : 'Tugas overdue',
        item.message,
        tz.TZDateTime.from(item.when, tz.local),
        const NotificationDetails(android: AndroidNotificationDetails(
          'nudge_deadlines', 'Deadline reminders',
          channelDescription: 'Reminder deadline tugas Nudge',
          importance: Importance.high, priority: Priority.high,
        )),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> rescheduleAll(List<Map<String, Object?>> tasks) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancelAll();
    for (final task in tasks) {
      final id = task['id'];
      final date = task['due_at'];
      if (id is int && date is String) {
        await scheduleTask(taskId: id, title: task['title'] as String? ?? 'Tugas', due: DateTime.parse(date), done: task['is_done'] == 1);
      }
    }
  }
}
