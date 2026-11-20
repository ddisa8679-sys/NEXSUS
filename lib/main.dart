import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final TextEditingController _intentionController = TextEditingController();
  static const String _intentionKey = 'nexsus_daily_intention_v1';
  static const String _intentionDateKey = 'nexsus_daily_intention_date_v1';
  bool _intentionSaved = false;

  @override
  void initState() {
    super.initState();
    _loadDailyIntention();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadDailyIntention() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (!mounted) return;
    if (prefs.getString(_intentionDateKey) == today) {
      _intentionController.text = prefs.getString(_intentionKey) ?? '';
      setState(() => _intentionSaved = _intentionController.text.isNotEmpty);
    }
  }

  Future<void> _saveDailyIntention() async {
    final value = _intentionController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.tx('Запиши один главный приоритет на сегодня.', 'Write down one priority for today.'))));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_intentionKey, value);
    await prefs.setString(_intentionDateKey, today);
    if (mounted) setState(() => _intentionSaved = true);
  }

  @override
  void dispose() {
    _intentionController.dispose();
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
      const SizedBox(height: 18),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_outlined, color: Color(0xFFFFD27A)),
          const SizedBox(width: 9),
          Expanded(child: Text(AppText.tx('Главный приоритет на сегодня', 'Your main priority today'), style: const TextStyle(fontWeight: FontWeight.bold))),
          if (_intentionSaved) const Icon(Icons.check_circle, color: Color(0xFF36D9A0), size: 18),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _intentionController,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: AppText.tx('Что действительно важно сегодня?', 'What really matters today?'),
            filled: true,
            fillColor: const Color(0xFF090D1B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
          ),
          onChanged: (_) { if (_intentionSaved) setState(() => _intentionSaved = false); },
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          onPressed: _saveDailyIntention,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(AppText.tx('Сохранить фокус дня', 'Save today’s focus')),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7652B8)),
        )),
      ])),
      const SizedBox(height: 22),
      Text(AppText.tx('БЫСТРЫЙ ДОСТУП', 'QUICK ACCESS'), style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4)),
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
