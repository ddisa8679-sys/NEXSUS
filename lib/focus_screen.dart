import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_text.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  static const _key = 'nexsus_focus_sessions_v1';
  static const _presets = [15, 25, 45, 60];
  int _minutes = 25, _remaining = 1500, _completed = 0;
  Timer? _timer;
  bool _running = false, _finished = false;
  DateTime? _endsAt;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _completed = p.getInt(_key) ?? 0);
  }
  String get _clock => '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}';
  double get _progress => 1 - _remaining / (_minutes * 60);

  void _select(int v) {
    if (_running) return;
    setState(() { _minutes = v; _remaining = v * 60; _finished = false; });
  }
  void _start() {
    if (_remaining <= 0) return;
    _timer?.cancel();
    _endsAt = DateTime.now().add(Duration(seconds: _remaining));
    setState(() { _running = true; _finished = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), _refreshRemaining);
  }

  void _refreshRemaining(Timer timer) {
    if (!mounted) { timer.cancel(); return; }
    final end = _endsAt;
    if (end == null) return;
    final seconds = end.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) { timer.cancel(); _complete(); }
    else { setState(() => _remaining = seconds); }
  }

  void _pause() {
    final end = _endsAt;
    if (end != null) _remaining = end.difference(DateTime.now()).inSeconds.clamp(0, _minutes * 60).toInt();
    _timer?.cancel();
    _endsAt = null;
    setState(() => _running = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running) _refreshRemaining(_timer ?? Timer(const Duration(seconds: 0), (_) {}));
  }
  Future<void> _complete() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_key) ?? 0) + 1;
    await p.setInt(_key, n);
    if (mounted) setState(() { _completed = n; _remaining = 0; _running = false; _finished = true; _endsAt = null; });
  }
  void _reset() {
    _timer?.cancel();
    _endsAt = null;
    setState(() { _running = false; _remaining = _minutes * 60; _finished = false; });
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(22, 26, 22, 32), children: [
    Text(AppText.tx('NEXSUS / РЕЖИМ ФОКУСА', 'NEXSUS / FOCUS MODE'), style: TextStyle(color: Color(0xFFFFD27A), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    Text(AppText.tx('Время для главного', 'Time for what matters'), style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text(AppText.tx('Убери лишнее. Выбери одну задачу. Остальное подождёт.', 'Clear the noise. Choose one task. The rest can wait.'), style: TextStyle(color: Colors.white60)),
    const SizedBox(height: 30),
    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF292044), Color(0xFF101426)]),
      border: Border.all(color: const Color(0x66B99AFF))),
      child: Column(children: [
        SizedBox(width: 218, height: 218, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: _progress, strokeWidth: 7, backgroundColor: Colors.white12, color: const Color(0xFFFFD27A), strokeCap: StrokeCap.round)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_clock, style: const TextStyle(fontSize: 49, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 5),
            Text(_finished ? AppText.tx('СЕССИЯ ЗАВЕРШЕНА', 'SESSION COMPLETE') : _running ? AppText.tx('СОСРЕДОТОЧЬСЯ', 'STAY FOCUSED') : AppText.tx('МИНУТЫ ДЛЯ СЕБЯ', 'TIME FOR YOURSELF'), style: const TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.white60)),
          ]),
        ])),
        const SizedBox(height: 25),
        Wrap(spacing: 8, children: _presets.map((v) => ChoiceChip(label: Text('$v мин'), selected: _minutes == v, onSelected: (_) => _select(v), selectedColor: const Color(0xFF7652B8), backgroundColor: const Color(0xFF202039), labelStyle: TextStyle(color: _minutes == v ? Colors.white : Colors.white70))).toList()),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _running ? _pause : _start, icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(_running ? AppText.tx('Пауза', 'Pause') : AppText.tx('Начать', 'Start')), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7652B8), padding: const EdgeInsets.symmetric(vertical: 14)))),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: _reset, icon: const Icon(Icons.refresh_rounded), tooltip: AppText.tx('Сбросить', 'Reset')),
        ]),
      ]),
    ),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF15182C), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Row(children: [
      const Icon(Icons.local_fire_department_outlined, color: Color(0xFFFFD27A), size: 30),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppText.tx('Завершённые сессии', 'Completed sessions'), style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4), Text('$_completed', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      ])),
      Text(AppText.tx('Каждая минута —\nшаг вперёд', 'Every minute is\na step forward'), textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 11)),
    ])),
    const SizedBox(height: 15),
    Text(AppText.tx('Совет: выбери одну задачу и не переключайся между приложениями до конца сессии.', 'Tip: choose one task and avoid switching apps until the session ends.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
  ]);
}
