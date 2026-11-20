import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'app_text.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _storageKey = 'nexsus_calendar_events_v1';
  static const _channelId = 'nexsus_calendar_reminders';
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final List<Map<String, dynamic>> _events = [];
  bool _loaded = false;
  bool _notificationsReady = false;
  bool _exactAlarmsAllowed = false;
  String _notificationStatus = AppText.tx('Подготавливаю уведомления…', 'Preparing notifications…');
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _notifications.initialize(const InitializationSettings(android: android));
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      _notificationsReady = granted ?? true;
      if (_notificationsReady) {
        _exactAlarmsAllowed = await androidPlugin?.requestExactAlarmsPermission() ?? false;
        await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId, AppText.tx('Напоминания календаря', 'Calendar reminders'),
          description: AppText.tx('Напоминания за день и в день важного события', 'Reminders one day before and on important dates'),
          importance: Importance.max,
        ));
      }
    } catch (_) {
      _notificationStatus = AppText.tx('Не удалось включить уведомления. Проверь разрешения Android.', 'Could not enable notifications. Check Android permissions.');
    }
    await _loadEvents();
    if (mounted) setState(() {
      _notificationStatus = !_notificationsReady
          ? AppText.tx('Разреши уведомления NEXSUS в настройках Android', 'Allow NEXSUS notifications in Android settings')
          : _exactAlarmsAllowed
              ? AppText.tx('Точные уведомления включены · за день и в день события', 'Exact reminders enabled · one day before and on the event day')
              : AppText.tx('Уведомления включены · Android может немного сдвигать время', 'Notifications enabled · Android may slightly adjust delivery time');
    });
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as List<dynamic>;
        _events.addAll(data.map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    _events.sort((a, b) => _nextDate(a).compareTo(_nextDate(b)));
    if (mounted) setState(() => _loaded = true);
    if (_notificationsReady) await _rescheduleAll();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_events));
  }

  DateTime _nextDate(Map<String, dynamic> event) {
    final date = DateTime.parse(event['date'] as String);
    if (event['yearly'] != true) return date;
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next;
  }

  int _notificationId(String id, int offset) =>
      ((int.tryParse(id) ?? id.hashCode).abs() % 100000000) * 2 + offset;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _scheduleEvent(Map<String, dynamic> event) async {
    if (!_notificationsReady) return;
    final eventId = event['id'] as String;
    final date = _nextDate(event);
    final title = event['title'] as String;
    final kind = event['kind'] as String? ?? AppText.tx('Важная дата', 'Important date');
    final yearly = event['yearly'] == true;
    final dayBefore = DateTime(date.year, date.month, date.day).subtract(const Duration(days: 1));
    final eventDay = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    var beforeTime = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9);
    var eventTime = DateTime(eventDay.year, eventDay.month, eventDay.day, 9);
    final beforeIsLateToday = _sameDate(dayBefore, now) && !beforeTime.isAfter(now);
    final eventIsLateToday = _sameDate(eventDay, now) && !eventTime.isAfter(now);
    if (beforeIsLateToday) beforeTime = now.add(const Duration(minutes: 1));
    if (eventIsLateToday) eventTime = now.add(const Duration(minutes: 1));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, AppText.tx('Напоминания календаря', 'Calendar reminders'),
        channelDescription: AppText.tx('За день и в день важного события', 'One day before and on the event day'),
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final baseId = _notificationId(eventId, 0);
    for (var offset = 0; offset < 4; offset++) {
      await _notifications.cancel(baseId + offset);
    }

    if (beforeTime.isAfter(now)) {
      await _notifications.zonedSchedule(
        baseId, 'Уже завтра: $title', '$kind — напоминание NEXSUS',
        tz.TZDateTime.from(beforeTime, tz.local), details,
        androidScheduleMode: _exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: yearly && !beforeIsLateToday ? DateTimeComponents.dateAndTime : null,
        payload: eventId,
      );
    }
    if (eventTime.isAfter(now)) {
      await _notifications.zonedSchedule(
        baseId + 1, 'Сегодня: $title', 'Наступила важная дата · $kind',
        tz.TZDateTime.from(eventTime, tz.local), details,
        androidScheduleMode: _exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: yearly && !eventIsLateToday ? DateTimeComponents.dateAndTime : null,
        payload: eventId,
      );
    }

    // If this year's reminder time has already passed, notify shortly and
    // separately schedule the correct 09:00 recurrence for next year.
    if (yearly && beforeIsLateToday) {
      final nextYear = DateTime(date.year + 1, date.month, date.day);
      final nextBefore = nextYear.subtract(const Duration(days: 1));
      final recurring = DateTime(nextBefore.year, nextBefore.month, nextBefore.day, 9);
      await _notifications.zonedSchedule(
        baseId + 2, 'Уже завтра: $title', '$kind — напоминание NEXSUS',
        tz.TZDateTime.from(recurring, tz.local), details,
        androidScheduleMode: _exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        payload: eventId,
      );
    }
    if (yearly && eventIsLateToday) {
      final nextYear = DateTime(date.year + 1, date.month, date.day);
      final recurring = DateTime(nextYear.year, nextYear.month, nextYear.day, 9);
      await _notifications.zonedSchedule(
        baseId + 3, 'Сегодня: $title', 'Наступила важная дата · $kind',
        tz.TZDateTime.from(recurring, tz.local), details,
        androidScheduleMode: _exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        payload: eventId,
      );
    }
  }

  Future<void> _rescheduleAll() async {
    for (final event in _events) {
      await _scheduleEvent(event);
    }
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    final details = TextEditingController();
    DateTime date = DateTime.now();
    String kind = AppText.tx('Важная дата', 'Important date');
    bool yearly = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text(AppText.tx('Новое событие', 'New event')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, decoration: InputDecoration(labelText: AppText.tx('Название события', 'Event title'))),
          TextField(controller: details, decoration: const InputDecoration(labelText: AppText.tx('Заметка (необязательно)', 'Note (optional)'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: kind,
            decoration: const InputDecoration(labelText: AppText.tx('Категория', 'Category')),
            items: ['День рождения', 'Праздник', 'Годовщина', 'Работа', 'Личное', AppText.tx('Важная дата', 'Important date')]
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { if (v != null) refresh(() => kind = v); },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context, initialDate: date,
                firstDate: DateTime(2000), lastDate: DateTime(2100),
              );
              if (picked != null) refresh(() => date = picked);
            },
            icon: const Icon(Icons.calendar_month),
            label: Text('${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: yearly,
            onChanged: (v) => refresh(() => yearly = v ?? false),
            title: Text(AppText.tx('Повторять каждый год', 'Repeat every year')),
            subtitle: Text(AppText.tx('Для дней рождения и ежегодных праздников', 'For birthdays and annual holidays')),
          ),
          Text(AppText.tx('Напоминания придут в 09:00 за день до события и в день события.', 'Reminders arrive at 09:00 one day before and on the event day.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(AppText.tx('Отмена', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text(AppText.tx('Сохранить', 'Save'))),
        ],
      )),
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      final event = <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': title.text.trim(),
        'details': details.text.trim(),
        'kind': kind,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'yearly': yearly,
      };
      setState(() {
        _events.add(event);
        _events.sort((a, b) => _nextDate(a).compareTo(_nextDate(b)));
      });
      await _save();
      await _scheduleEvent(event);
    }
    title.dispose();
    details.dispose();
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final id = event['id'] as String;
    final baseId = _notificationId(id, 0);
    await _notifications.cancel(baseId);
    for (var offset = 1; offset < 4; offset++) {
      await _notifications.cancel(baseId + offset);
    }
    setState(() => _events.removeWhere((e) => e['id'] == id));
    await _save();
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = _events.where((e) => !_nextDate(e).isBefore(DateTime(now.year, now.month, now.day))).toList()
      ..sort((a, b) => _nextDate(a).compareTo(_nextDate(b)));
    final days = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstOffset = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1;
    final marked = _events.map(_nextDate).where((d) => d.year == _selectedMonth.year && d.month == _selectedMonth.month).map((d) => d.day).toSet();
    final monthNames = AppText.language == 'en' ? ['January','February','March','April','May','June','July','August','September','October','November','December'] : ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _addEvent, icon: const Icon(Icons.add), label: Text(AppText.tx('Добавить дату', 'Add date'))),
      body: SafeArea(child: !_loaded ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
        children: [
          const Text('NEXSUS / CALENDAR', style: TextStyle(color: Color(0xFFFFD27A), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(AppText.tx('Твои важные даты', 'Your important dates'), style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text(_notificationStatus, style: TextStyle(fontSize: 11, color: _notificationsReady ? const Color(0xFF55D6A4) : Colors.orangeAccent)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF15182C), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x557650D8))),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
                Expanded(child: Text('${monthNames[_selectedMonth.month - 1].toUpperCase()} ${_selectedMonth.year}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                IconButton(onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                'ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС'
              ].map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold))))).toList(),
              ),
              const SizedBox(height: 8),
              ...List.generate((firstOffset + days + 6) ~/ 7, (week) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: List.generate(7, (col) {
                  final day = week * 7 + col - firstOffset + 1;
                  if (day < 1 || day > days) return const Expanded(child: SizedBox(height: 38));
                  final isToday = day == now.day && _selectedMonth.year == now.year && _selectedMonth.month == now.month;
                  final hasEvent = marked.contains(day);
                  return Expanded(child: Container(
                    height: 38,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday ? const Color(0xFF7650D8) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: hasEvent && !isToday ? Border.all(color: const Color(0xFFFFD27A)) : null,
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      Text('$day', style: TextStyle(fontWeight: isToday || hasEvent ? FontWeight.bold : FontWeight.normal)),
                      if (hasEvent) const Positioned(bottom: 3, child: Icon(Icons.circle, size: 4, color: Color(0xFFFFD27A))),
                    ]),
                  ));
                })),
              )),
            ]),
          ),
          const SizedBox(height: 22),
          Row(children: [Expanded(child: Text(AppText.tx('БЛИЖАЙШИЕ СОБЫТИЯ', 'UPCOMING EVENTS'), style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2))), Text('${upcoming.length}', style: const TextStyle(color: Color(0xFFFFD27A)))]),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Column(children: [
              Icon(Icons.event_available, size: 46, color: Color(0xFFB99AFF)),
              SizedBox(height: 10),
              Text(AppText.tx('Пока нет важных дат', 'No important dates yet'), style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(AppText.tx('Добавь день рождения, праздник или любую памятную дату.', 'Add a birthday, holiday, or any date worth remembering.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]))
          else
            ...upcoming.map((event) {
              final date = _nextDate(event);
              final yearly = event['yearly'] == true;
              final detail = (event['details'] as String? ?? '').trim();
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF15182C), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x332D2C4A))),
                child: Row(children: [
                  Container(width: 48, height: 52, decoration: BoxDecoration(color: const Color(0xFF30234F), borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(date.day.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    Text(monthNames[date.month - 1].substring(0, 3), style: const TextStyle(fontSize: 10, color: Color(0xFFFFD27A))),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(event['title'] as String? ?? 'Событие', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text('${event['kind']} · ${_dateLabel(date)}${yearly ? ' · ежегодно' : ''}', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    if (detail.isNotEmpty) Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ])),
                  IconButton(onPressed: () => _deleteEvent(event), tooltip: AppText.tx('Удалить событие', 'Delete event'), icon: const Icon(Icons.delete_outline, color: Colors.white38)),
                ]),
              );
            }),
          const SizedBox(height: 8),
          const Text(AppText.tx('Напоминания планируются на устройстве. Для своевременной доставки не отключай уведомления NEXSUS и разрешение точных будильников в Android.', 'Reminders are scheduled on this device. Keep NEXSUS notifications and exact alarm permission enabled for timely delivery.'), style: TextStyle(fontSize: 10, color: Colors.white38, height: 1.4)),
        ],
      )),
    );
  }
}
