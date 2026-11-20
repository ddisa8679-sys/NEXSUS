import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const _storageKey = 'nexsus_tasks_v1';
  final List<Map<String, dynamic>> _tasks = [];
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;
  bool _exactAlarmsAllowed = false;
  bool _loaded = false;

  @override
  void initState() { super.initState(); _initializeNotifications(); _load(); }

  Future<void> _initializeNotifications() async {
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
      await _notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      _notificationsReady = await android?.requestNotificationsPermission() ?? true;
      if (_notificationsReady) {
        _exactAlarmsAllowed = await android?.requestExactAlarmsPermission() ?? false;
        await android?.createNotificationChannel(const AndroidNotificationChannel('nexsus_task_reminders', 'Напоминания о задачах', description: 'Напоминания о задачах за день до срока', importance: Importance.max));
        for (final task in _tasks) { await _scheduleReminder(task); }
      }
    } catch (_) { _notificationsReady = false; }
  }

  int _notificationId(String id) => (int.tryParse(id) ?? id.hashCode).abs() % 2000000000;

  Future<void> _scheduleReminder(Map<String, dynamic> task) async {
    if (!_notificationsReady || task['done'] == true) return;
    final due = _dateOf(task);
    if (due == null) return;
    final reminder = due.subtract(const Duration(days: 1));
    if (!reminder.isAfter(DateTime.now())) return;
    await _notifications.zonedSchedule(
      _notificationId(task['id'] as String), 'Завтра: ${task['title']}',
      'Срок задачи наступит завтра. Проверь свой план в NEXSUS.',
      tz.TZDateTime.from(reminder, tz.local),
      const NotificationDetails(android: AndroidNotificationDetails('nexsus_task_reminders', 'Напоминания о задачах', channelDescription: 'Напоминания о задачах за день до срока', importance: Importance.max, priority: Priority.high, category: AndroidNotificationCategory.reminder)),
      androidScheduleMode: _exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: task['id'] as String,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _tasks.addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
    if (_notificationsReady) { for (final task in _tasks) { await _scheduleReminder(task); } }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_tasks));
  }

  DateTime? _dateOf(Map<String, dynamic> task) {
    final value = task['due'] as String?;
    return value == null ? null : DateTime.tryParse(value);
  }

  bool _sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;
  bool _overdue(Map<String, dynamic> task) {
    final d = _dateOf(task), now = DateTime.now();
    return task['done'] != true && d != null && DateTime(d.year, d.month, d.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    String priority = 'Обычный';
    DateTime? due;
    TimeOfDay dueTime = const TimeOfDay(hour: 9, minute: 0);
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) => AlertDialog(
      title: const Text('Новая задача'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Что нужно сделать?')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'Приоритет'), items: const [
          DropdownMenuItem(value: 'Низкий', child: Text('Низкий')),
          DropdownMenuItem(value: 'Обычный', child: Text('Обычный')),
          DropdownMenuItem(value: 'Высокий', child: Text('Высокий')),
        ], onChanged: (v) { if (v != null) refresh(() => priority = v); }),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: due ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
          if (picked != null) refresh(() => due = picked);
        }, icon: const Icon(Icons.calendar_today_outlined), label: Text(due == null ? 'Добавить срок' : due!.day.toString().padLeft(2,'0') + '.' + due!.month.toString().padLeft(2,'0') + '.' + due!.year.toString())),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async {
          final picked = await showTimePicker(context: context, initialTime: dueTime);
          if (picked != null) refresh(() => dueTime = picked);
        }, icon: const Icon(Icons.access_time), label: Text('Время: ${dueTime.format(context)}')),
        const SizedBox(height: 6),
        const Text('Напоминание придёт за день до срока в выбранное время.', style: TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Добавить')),
      ],
    )));
    if (result == true && controller.text.trim().isNotEmpty) {
      final dueAt = due == null ? null : DateTime(due!.year, due!.month, due!.day, dueTime.hour, dueTime.minute);
      final task = {'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': controller.text.trim(), 'priority': priority, 'due': dueAt?.toIso8601String(), 'done': false, 'created': DateTime.now().toIso8601String()};
      setState(() => _tasks.insert(0, task));
      await _save();
      await _scheduleReminder(task);
    }
    controller.dispose();
  }

  Future<void> _toggle(int index, bool value) async {
    setState(() => _tasks[index]['done'] = value);
    if (value) await _notifications.cancel(_notificationId(_tasks[index]['id'] as String)); else await _scheduleReminder(_tasks[index]);
    await _save();
  }

  Future<void> _delete(int index) async {
    final removed = _tasks.removeAt(index);
    await _notifications.cancel(_notificationId(removed['id'] as String));
    setState(() {});
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = _tasks.where((t) => t['done'] != true).length;
    final today = _tasks.where((t) => t['done'] != true && _sameDay(_dateOf(t), now)).length;
    final overdue = _tasks.where(_overdue).length;
    final completed = _tasks.where((t) => t['done'] == true).length;
    final sorted = List<int>.generate(_tasks.length, (i) => i)..sort((a,b) {
      final da = _dateOf(_tasks[a]), db = _dateOf(_tasks[b]);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    final dateLabel = now.day.toString().padLeft(2,'0') + '.' + now.month.toString().padLeft(2,'0') + '.' + now.year.toString();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _addTask, icon: const Icon(Icons.add), label: const Text('Новая задача')),
      body: SafeArea(child: !_loaded ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 100), children: [
        const Text('NEXSUS / SMART TASKS', style: TextStyle(color: Color(0xFFFFD27A), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Твой план действий', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text('Сводка на ' + dateLabel, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFF282044), Color(0xFF111629)]), border: Border.all(color: const Color(0x66B99AFF))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.wb_twilight, color: Color(0xFFFFD27A)), SizedBox(width: 9), Text('ЕЖЕДНЕВНАЯ СВОДКА', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))]),
          const SizedBox(height: 14),
          Row(children: [
            _metric('Активные', active.toString()),
            _metric('На сегодня', today.toString()),
            _metric('Просрочено', overdue.toString()),
            _metric('Готово', completed.toString()),
          ]),
          const SizedBox(height: 12),
          Text(active == 0 ? 'Свободный день: активных задач пока нет.' : overdue > 0 ? 'Есть задачи с истёкшим сроком. Начни с них.' : today > 0 ? 'На сегодня запланировано ' + today.toString() + ' задач. Выбери одну и начни.' : 'План есть. Добавь срок задачам, чтобы видеть приоритет дня.', style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        ])),
        const SizedBox(height: 22),
        Row(children: [const Expanded(child: Text('СПИСОК ЗАДАЧ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.3))), Text(active.toString() + ' осталось', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12))]),
        const SizedBox(height: 10),
        if (_tasks.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 35), child: Column(children: [Icon(Icons.checklist_rounded, size: 48, color: Color(0xFFB99AFF)), SizedBox(height: 12), Text('Пока задач нет', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 5), Text('Добавь первую задачу — сводка начнёт собираться автоматически.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))]))
        else ...sorted.map((i) {
          final task = _tasks[i], due = _dateOf(task), done = task['done'] == true, late = _overdue(task);
          final priority = task['priority'] as String? ?? 'Обычный';
          final dueLabel = due == null ? '' : 'Срок: ' + due.day.toString().padLeft(2,'0') + '.' + due.month.toString().padLeft(2,'0') + '.' + due.year.toString() + ' · ' + TimeOfDay.fromDateTime(due).format(context);
          return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: const Color(0xFF15182C), borderRadius: BorderRadius.circular(16), border: Border.all(color: late ? const Color(0x88E36C75) : Colors.white10)), child: Row(children: [
            Checkbox(value: done, onChanged: (v) => _toggle(i, v ?? false), activeColor: const Color(0xFF7652B8)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task['title'] as String? ?? 'Без названия', style: TextStyle(fontWeight: FontWeight.w600, decoration: done ? TextDecoration.lineThrough : null, color: done ? Colors.white54 : Colors.white)),
              const SizedBox(height: 4),
              Text([priority, if (dueLabel.isNotEmpty) dueLabel, if (late) 'Просрочено'].join(' · '), style: TextStyle(fontSize: 10, color: late ? const Color(0xFFFF858D) : Colors.white54)),
            ])),
            IconButton(onPressed: () => _delete(i), icon: const Icon(Icons.delete_outline, color: Colors.white38), tooltip: 'Удалить'),
          ]));
        }),
      ])),
    );
  }

  Widget _metric(String label, String value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60))]));
}
