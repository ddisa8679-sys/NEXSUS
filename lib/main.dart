import 'dart:async';
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
import 'nexsus_theme.dart';
import 'profile_screen.dart';
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
      theme: NexsusTheme.build(accentColor: _settings.accent, fontFamily: _settings.fontFamily).copyWith(
        scaffoldBackgroundColor: _settings.scaffoldColor,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_settings.fontScale),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: widget.firebaseReady && FirebaseAuth.instance.currentUser != null
          ? HomeScreen(
              nickname: FirebaseAuth.instance.currentUser!.displayName ??
                  (FirebaseAuth.instance.currentUser!.email?.split('@').first ?? 'NEXSUS'),
              settings: _settings,
              firebaseReady: widget.firebaseReady,
            )
          : AuthScreen(
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _selected = 0;
  final Set<int> _visitedTabs = {0};
  final TextEditingController _intentionController = TextEditingController();
  static const String _intentionKey = 'nexsus_daily_intention_v1';
  static const String _intentionDateKey = 'nexsus_daily_intention_date_v1';
  bool _intentionSaved = false;
  static const String _selectedTabKey = 'nexsus_selected_tab_v1';
  static const String _goodDeedDateKey = 'nexsus_good_deed_date_v1';
  static const String _goodDeedDoneKey = 'nexsus_good_deed_done_v1';
  bool _goodDeedDone = false;
  static const List<String> _goodDeeds = [
    'Напиши близкому человеку и спроси, как у него дела.',
    'Помоги кому-нибудь с небольшим делом, не ожидая благодарности.',
    'Сдай батарейки или пластик в подходящий пункт приёма.',
    'Поделись полезным знанием или поддержи начинающего.',
    'Поблагодари человека, чей труд часто остаётся незаметным.',
    'Уступи место или помоги человеку, которому это нужно.',
    'Убери небольшой участок вокруг себя — двор, парк или рабочее место.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreHomeState();
    _loadDailyIntention();
    _loadGoodDeed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _restoreHomeState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTab = (prefs.getInt(_selectedTabKey) ?? 0).clamp(0, 4);
    if (!mounted) return;
    setState(() { _selected = savedTab; _visitedTabs.add(savedTab); });
  }

  Future<void> _saveSelectedTab(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTabKey, value);
  }

  Future<void> _loadGoodDeed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (!mounted) return;
    setState(() => _goodDeedDone =
        prefs.getString(_goodDeedDateKey) == today &&
        prefs.getBool(_goodDeedDoneKey) == true);
  }

  int get _goodDeedIndex =>
      DateTime.now().difference(DateTime(2025, 1, 1)).inDays.abs() % _goodDeeds.length;

  Future<void> _completeGoodDeed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_goodDeedDateKey, today);
    await prefs.setBool(_goodDeedDoneKey, true);
    if (mounted) setState(() => _goodDeedDone = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() => _now = DateTime.now());
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
    WidgetsBinding.instance.removeObserver(this);
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
          onDestinationSelected: (value) {
            setState(() { _visitedTabs.add(value); _selected = value; });
            _saveSelectedTab(value);
          },
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
        const Icon(Icons.circle, color: Color(0xFF8BC9A5), size: 8),
        const SizedBox(width: 6),
        Text(AppText.tx('ЛИЧНОЕ ПРОСТРАНСТВО', 'PERSONAL SPACE'), style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .55), letterSpacing: 1)),
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
          Text('${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}', style: TextStyle(color: widget.settings.accent, fontSize: 17, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text(AppText.tx('Пользователь NEXSUS', 'NEXSUS user'), style: TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        Icon(Icons.verified, color: widget.settings.accent),
      ])),
      const SizedBox(height: 18),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_outlined, color: Color(0xFFB7A2F6)),
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
            fillColor: const Color(0xFF22252A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
          ),
          onChanged: (_) { if (_intentionSaved) setState(() => _intentionSaved = false); },
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          onPressed: _saveDailyIntention,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(AppText.tx('Сохранить фокус дня', 'Save today’s focus')),
          style: FilledButton.styleFrom(backgroundColor: widget.settings.accent, foregroundColor: const Color(0xFF17131F)),
        )),
      ])),
      const SizedBox(height: 18),
      _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.volunteer_activism_outlined, color: widget.settings.accent),
          const SizedBox(width: 9),
          Expanded(child: Text(AppText.tx('Доброе дело дня', 'A good deed today'),
              style: const TextStyle(fontWeight: FontWeight.bold))),
          if (_goodDeedDone) const Icon(Icons.check_circle, color: Color(0xFF36D9A0)),
        ]),
        const SizedBox(height: 9),
        Text(_goodDeeds[_goodDeedIndex], style: const TextStyle(height: 1.4)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(
          onPressed: _goodDeedDone ? null : _completeGoodDeed,
          icon: Icon(_goodDeedDone ? Icons.check : Icons.favorite_border),
          label: Text(_goodDeedDone
              ? AppText.tx('На сегодня выполнено', 'Done for today')
              : AppText.tx('Сделано', 'I did it')),
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
          _action(Icons.calendar_month, AppText.tx('Календарь', 'Calendar'), AppText.tx('Дни рождения и события', 'Birthdays and events'), 3),
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
    onTap: () { if (page == 7) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksScreen())); } else { setState(() { _visitedTabs.add(page); _selected = page; }); _saveSelectedTab(page); } },
    child: Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A1C20),
        border: Border.all(color: const Color(0xFF303238)),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: widget.settings.accent, size: 23),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ]),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: const Color(0xFF1A1C20),
      border: Border.all(color: const Color(0xFF303238)),
    ),
    child: child,
  );
}

class _NexsusAvatar extends StatelessWidget {
  const _NexsusAvatar({this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF292B31),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF454850)),
    ),
    child: Text(
      'N',
      style: TextStyle(
        fontSize: size * .48,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
