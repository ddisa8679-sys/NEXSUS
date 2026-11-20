import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import 'jarvis_screen.dart';
import 'notes_screen.dart';
import 'app_settings.dart';
import 'app_text.dart';
import 'profile_screen.dart';
import 'focus_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';

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

class NexsusApp extends StatefulWidget {
  const NexsusApp({super.key, required this.firebaseReady});
  final bool firebaseReady;
  @override
  State<NexsusApp> createState() => _NexsusAppState();
}

class _NexsusAppState extends State<NexsusApp> {
  final AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _settings,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEXSUS',
      locale: Locale(_settings.language),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _settings.scaffoldColor,
        colorScheme: ColorScheme.fromSeed(seedColor: _settings.accent, brightness: Brightness.dark),
        fontFamily: _settings.fontFamily,
        useMaterial3: true,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_settings.fontScale),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: AuthScreen(
        firebaseReady: widget.firebaseReady,
        onAuthenticated: (context, nickname) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(nickname: nickname, settings: _settings, firebaseReady: widget.firebaseReady)),
          );
        },
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.nickname, required this.settings, required this.firebaseReady});
  final String nickname;
  final AppSettings settings;
  final bool firebaseReady;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _selected = 0;
  final Set<int> _visitedTabs = {0};

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
    if (hour >= 5 && hour < 12) return AppText.tx('Доброе утро', 'Good morning');
    if (hour >= 12 && hour < 18) return AppText.tx('Добрый день', 'Good afternoon');
    if (hour >= 18 && hour < 23) return AppText.tx('Добрый вечер', 'Good evening');
    return AppText.tx('Доброй ночи', 'Good night');
  }

  String get _date => '${_weekday(_now.weekday)}, ${_now.day} ${_month(_now.month)} ${_now.year}';
  String _weekday(int day) => const [AppText.tx('Понедельник', 'Monday'),AppText.tx('Вторник', 'Tuesday'),AppText.tx('Среда', 'Wednesday'),AppText.tx('Четверг', 'Thursday'),AppText.tx('Пятница', 'Friday'),AppText.tx('Суббота', 'Saturday'),AppText.tx('Воскресенье', 'Sunday')][day - 1];
  String _month(int month) => const [AppText.tx('января', 'Jan'),AppText.tx('февраля', 'Feb'),AppText.tx('марта', 'Mar'),AppText.tx('апреля', 'Apr'),AppText.tx('мая', 'May'),AppText.tx('июня', 'Jun'),AppText.tx('июля', 'Jul'),AppText.tx('августа', 'Aug'),AppText.tx('сентября', 'Sep'),AppText.tx('октября', 'Oct'),AppText.tx('ноября', 'Nov'),AppText.tx('декабря', 'Dec')][month - 1];
  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      _visitedTabs.contains(1) ? JarvisScreen(nickname: widget.nickname) : const SizedBox.shrink(),
      _visitedTabs.contains(2) ? const NotesScreen() : const SizedBox.shrink(),
      _visitedTabs.contains(3) ? const CalendarScreen() : const SizedBox.shrink(),
      _visitedTabs.contains(4) ? ProfileScreen(nickname: widget.nickname, settings: widget.settings, onSignOut: () async { await FirebaseAuth.instance.signOut(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => AuthScreen(firebaseReady: widget.firebaseReady, onAuthenticated: (ctx, name) { Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(nickname: name, settings: widget.settings, firebaseReady: widget.firebaseReady))); })), (route) => false); }) : const SizedBox.shrink(),
    ];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Expanded(child: IndexedStack(index: _selected, children: pages)),
        NavigationBar(
          selectedIndex: _selected,
          onDestinationSelected: (value) => setState(() {
            _visitedTabs.add(value);
            _selected = value;
          }),
          destinations: [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: AppText.tx('Главная', 'Home')),
            NavigationDestination(icon: Icon(Icons.graphic_eq), label: AppText.tx('Джарвис', 'Jarvis')),
            NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), label: AppText.tx('Заметки', 'Notes')),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: AppText.tx('Календарь', 'Calendar')),
            NavigationDestination(icon: Icon(Icons.person_outline), label: AppText.tx('Профиль', 'Profile')),
          ],
        ),
      ])),
    );
  }

  Widget _dashboard() {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 28), children: [
      Row(children: [
        const _NexsusAvatar(size: 38),
        const SizedBox(width: 10),
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
        Text(AppText.tx('Рады снова тебя видеть.', 'Good to see you again.'), style: TextStyle(color: Colors.white.withValues(alpha: .65))),
      ])),
      const SizedBox(height: 16),
      _panel(child: Row(children: [
        const _NexsusAvatar(size: 62),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.nickname, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(AppText.tx('Пользователь NEXSUS', 'NEXSUS user'), style: TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        const Icon(Icons.verified, color: Color(0xFFFFD27A)),
      ])),
      const SizedBox(height: 22),
      const Text(AppText.tx('БЫСТРЫЙ ДОСТУП', 'QUICK ACCESS'), style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
        children: [
          _action(Icons.mic, AppText.tx('Джарвис', 'Jarvis'), AppText.tx('Голосовой помощник', 'Voice assistant'), 1),
          _action(Icons.note_alt_outlined, AppText.tx('Заметки', 'Notes'), AppText.tx('Быстрые записи', 'Quick notes'), 2),
          _action(Icons.person_outline, AppText.tx('Профиль', 'Profile'), AppText.tx('Личные данные и настройки', 'Personal details and settings'), 4),
          _action(Icons.calendar_month, AppText.tx('Календарь', 'Calendar'), AppText.tx('Дни рождения и события', 'Birthdays and events'), 3),
          _action(Icons.center_focus_strong, AppText.tx('Фокус', 'Focus'), AppText.tx('Таймер концентрации', 'Focus timer'), 6),
          _action(Icons.checklist_rounded, AppText.tx('Мои задачи', 'My tasks'), AppText.tx('План и сводка дня', 'Daily plan and summary'), 7),
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
    onTap: () { if (page == 6) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusScreen())); } else if (page == 7) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksScreen())); } else { setState(() { _visitedTabs.add(page); _selected = page; }); } },
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

class _ClockPage extends StatelessWidget {
  const _ClockPage({required this.now, required this.date});

  final DateTime now;
  final String date;

  @override
  Widget build(BuildContext context) {
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final seconds = now.second.toString().padLeft(2, '0');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 34, color: Color(0xFFFFD27A)),
            const SizedBox(height: 24),
            Text(time, style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w300, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()])),
            Text(seconds, style: const TextStyle(fontSize: 20, color: Color(0xFFFFD27A), letterSpacing: 3)),
            const SizedBox(height: 16),
            Text(date, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.white60)),
            const SizedBox(height: 28),
            const Text('ТВОЁ ВРЕМЯ. ТВОЙ РИТМ.', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
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

 
class _NexsusAvatar extends StatelessWidget {
  const _NexsusAvatar({this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF493019), Color(0xFF17111A), Color(0xFF080A13)],
          stops: [0, .58, 1],
        ),
        border: Border.all(color: const Color(0xFFFFD27A), width: size * .035),
        boxShadow: const [
          BoxShadow(color: Color(0x66FFB84D), blurRadius: 13, spreadRadius: 1),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.42,
            child: Container(
              width: size * .78,
              height: size * .30,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFD27A), width: size * .025),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Text(
            'N',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: size * .68,
              height: 1,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFD27A),
              shadows: const [Shadow(color: Color(0xFFFFA629), blurRadius: 12)],
            ),
          ),
          Positioned(
            top: size * .10,
            right: size * .18,
            child: Container(
              width: size * .07,
              height: size * .07,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0C2),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0xFFFFC45C), blurRadius: 7)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
