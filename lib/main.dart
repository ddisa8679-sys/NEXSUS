import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    // Keep the UI usable and show setup guidance when auth is attempted.
  }
  runApp(NexsusApp(firebaseReady: firebaseReady));
}

class NexsusApp extends StatelessWidget {
  const NexsusApp({super.key, required this.firebaseReady});
  final bool firebaseReady;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'NEXSUS',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070817),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8050FF), brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: AuthScreen(
      firebaseReady: firebaseReady,
      onAuthenticated: (context, nickname) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(nickname: nickname)),
        );
      },
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.nickname});
  final String nickname;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour >= 5 && hour < 12) return 'Доброе утро';
    if (hour >= 12 && hour < 18) return 'Добрый день';
    if (hour >= 18 && hour < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }

  String get _date => '${_weekday(_now.weekday)}, ${_now.day} ${_month(_now.month)} ${_now.year}';
  String _weekday(int day) => const ['Понедельник','Вторник','Среда','Четверг','Пятница','Суббота','Воскресенье'][day - 1];
  String _month(int month) => const ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'][month - 1];
  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      const _PlaceholderPage(icon: Icons.graphic_eq, title: 'Джарвис', subtitle: 'Голосовой помощник появится на следующем этапе.'),
      const _PlaceholderPage(icon: Icons.note_alt_outlined, title: 'Быстрые заметки', subtitle: 'Здесь будут ваши заметки.'),
      const _PlaceholderPage(icon: Icons.access_time, title: 'Цифровой Блат', subtitle: 'Персональный цифровой циферблат.'),
      const _PlaceholderPage(icon: Icons.person_outline, title: 'Профиль', subtitle: 'Настройки профиля и аватара.'),
    ];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Expanded(child: IndexedStack(index: _selected, children: pages)),
        NavigationBar(
          selectedIndex: _selected,
          onDestinationSelected: (value) => setState(() => _selected = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
            NavigationDestination(icon: Icon(Icons.graphic_eq), label: 'Джарвис'),
            NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), label: 'Заметки'),
            NavigationDestination(icon: Icon(Icons.schedule), label: 'Часы'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
          ],
        ),
      ])),
    );
  }

  Widget _dashboard() {
    final time = '${_two(_now.hour)}:${_two(_now.minute)}:${_two(_now.second)}';
    return ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 28), children: [
      Row(children: [
        const Icon(Icons.bolt, color: Color(0xFFB18CFF), size: 30),
        const SizedBox(width: 8),
        const Text('NEXSUS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
        const Spacer(),
        const Icon(Icons.circle, color: Color(0xFF36D9A0), size: 9),
        const SizedBox(width: 6),
        Text('ЛИЧНОЕ ПРОСТРАНСТВО', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .55), letterSpacing: 1)),
      ]),
      const SizedBox(height: 28),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$_greeting, ${widget.nickname}!', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text('Рады снова тебя видеть.', style: TextStyle(color: Colors.white.withValues(alpha: .65))),
        const SizedBox(height: 22),
        Text(time, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w300, color: Color(0xFFB99AFF), letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(_date, style: TextStyle(color: Colors.white.withValues(alpha: .65))),
      ])),
      const SizedBox(height: 16),
      _panel(child: Row(children: [
        Container(width: 62, height: 62, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8C4DFF), Color(0xFF236BFF)])), child: const Icon(Icons.person, size: 38)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.nickname, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Пользователь NEXSUS', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        const Icon(Icons.verified, color: Color(0xFF38DDA4)),
      ])),
      const SizedBox(height: 22),
      const Text('БЫСТРЫЙ ДОСТУП', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
        children: [
          _action(Icons.mic, 'Джарвис', 'Голосовой помощник', 1),
          _action(Icons.note_alt_outlined, 'Заметки', 'Быстрые записи', 2),
          _action(Icons.watch_later_outlined, 'Цифровой Блат', 'Твои часы', 3),
          _action(Icons.person_outline, 'Профиль', 'Личные данные', 4),
        ],
      ),
      const SizedBox(height: 18),
      _panel(child: const Row(children: [
        Icon(Icons.shield_outlined, color: Color(0xFF39DDA4), size: 28),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NEXSUS запущен', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Первый экран Android', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
      ])),
    ]);
  }

  Widget _action(IconData icon, String title, String subtitle, int page) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => setState(() => _selected = page),
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF21164A), Color(0xFF101A38)]),
        border: Border.all(color: const Color(0xFF7650D8).withValues(alpha: .45)),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFFB99AFF), size: 25),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ]),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF171832), Color(0xFF0D1025)]),
      border: Border.all(color: const Color(0xFF6745BD).withValues(alpha: .42)),
    ),
    child: child,
  );
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 58, color: const Color(0xFFB99AFF)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
    ]),
  ));
}
