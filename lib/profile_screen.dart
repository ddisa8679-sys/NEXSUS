import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_settings.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.nickname,
    required this.settings,
  });

  final String nickname;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          const Text('ЛИЧНЫЙ КАБИНЕТ', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFFFFD27A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Профиль и настройки', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _section(
            child: Row(children: [
              CircleAvatar(radius: 31, backgroundColor: settings.accent.withValues(alpha: .22), child: Icon(Icons.person, color: settings.accent, size: 34)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nickname, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(user?.email ?? 'Локальный профиль', style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ])),
              Icon(Icons.verified_user_outlined, color: settings.accent),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('ЯЗЫК И ИНТЕРФЕЙС', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Язык приложения', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings.language,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.language)),
              items: const [
                DropdownMenuItem(value: 'ru', child: Text('Русский')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) { if (value != null) settings.setLanguage(value); },
            ),
            const SizedBox(height: 6),
            const Text('Язык системных элементов и календарных диалогов изменится сразу. Перевод остальных экранов будет расширяться в следующих обновлениях.', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
          const SizedBox(height: 22),
          const Text('ВНЕШНИЙ ВИД', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Цвет интерфейса', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _colorChoice('violet', const Color(0xFF8050FF), settings),
              _colorChoice('blue', const Color(0xFF398BFF), settings),
              _colorChoice('emerald', const Color(0xFF24B889), settings),
              _colorChoice('rose', const Color(0xFFE45D9A), settings),
              _colorChoice('amber', const Color(0xFFFFB84D), settings),
              _colorChoice('cyan', const Color(0xFF22C7D6), settings),
              _colorChoice('crimson', const Color(0xFFE34D65), settings),
            ]),
            const Divider(height: 28, color: Colors.white12),
            const Text('Фон приложения', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choice(context, 'midnight', 'Тёмно-фиолетовый', settings.background, (v) => settings.setBackground(v)),
            _choice(context, 'black', 'Чёрный OLED', settings.background, (v) => settings.setBackground(v)),
            _choice(context, 'navy', 'Тёмно-синий', settings.background, (v) => settings.setBackground(v)),
            const Divider(height: 28, color: Colors.white12),
            const Text('Шрифт', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choice(context, 'system', 'Стандартный', settings.font, (v) => settings.setFont(v)),
            _choice(context, 'serif', 'С засечками', settings.font, (v) => settings.setFont(v)),
            _choice(context, 'mono', 'Моноширинный', settings.font, (v) => settings.setFont(v)),
            const Divider(height: 28, color: Colors.white12),
            Row(children: [
              const Expanded(child: Text('Размер текста', style: TextStyle(fontWeight: FontWeight.w600))),
              Text('${(settings.fontScale * 100).round()}%', style: TextStyle(color: settings.accent, fontWeight: FontWeight.bold)),
            ]),
            Slider(
              value: settings.fontScale,
              min: .85,
              max: 1.25,
              divisions: 8,
              activeColor: settings.accent,
              onChanged: settings.setFontScale,
            ),
          ])),
          const SizedBox(height: 22),
          const Text('АККАУНТ', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _section(child: Column(children: [
            _accountRow(Icons.mail_outline, 'Электронная почта', user?.email ?? 'Не подключена'),
            const Divider(height: 22, color: Colors.white12),
            _accountRow(Icons.security_outlined, 'Безопасность', user?.emailVerified == true ? 'Почта подтверждена' : 'Почта не подтверждена'),
            const Divider(height: 22, color: Colors.white12),
            _accountRow(Icons.info_outline, 'Версия приложения', 'NEXSUS 0.1.0'),
          ])),
          const SizedBox(height: 14),
          Text('Настройки внешнего вида сохраняются на этом устройстве.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .48), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _section({required Widget child}) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFF15182C),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x334D4A70)),
    ),
    child: child,
  );

  Widget _colorChoice(String value, Color color, AppSettings settings) => GestureDetector(
    onTap: () => settings.setTheme(value),
    child: Container(
      width: 37, height: 37,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color,
        border: Border.all(color: settings.theme == value ? Colors.white : Colors.transparent, width: 3)),
      child: settings.theme == value ? const Icon(Icons.check, color: Colors.white, size: 19) : null,
    ),
  );

  Widget _choice(BuildContext context, String value, String label, String selected, ValueChanged<String> onSelect) =>
    RadioListTile<String>(
      dense: true, contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
      activeColor: settingsColor(context), value: value, groupValue: selected,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onChanged: (v) { if (v != null) onSelect(v); },
    );

  Color settingsColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  Widget _accountRow(IconData icon, String title, String value) => Row(children: [
    Icon(icon, color: const Color(0xFFB99AFF), size: 21),
    const SizedBox(width: 12),
    Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
    Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 11, color: Colors.white54))),
  ]);
}
