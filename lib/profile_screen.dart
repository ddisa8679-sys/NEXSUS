import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_settings.dart';
import 'app_text.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.nickname,
    required this.settings,
    required this.onSignOut,
  });

  final String nickname;
  final AppSettings settings;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          Text(AppText.tx('ЛИЧНЫЙ КАБИНЕТ', 'PERSONAL SPACE'), style: TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFFFFD27A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppText.tx('Профиль и настройки', 'Profile & settings'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _section(
            child: Row(children: [
              CircleAvatar(radius: 31, backgroundColor: settings.accent.withValues(alpha: .22), child: Icon(Icons.person, color: settings.accent, size: 34)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nickname, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(user?.email ?? AppText.tx('Локальный профиль', 'Local profile'), style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ])),
              Icon(Icons.verified_user_outlined, color: settings.accent),
            ]),
          ),
          const SizedBox(height: 22),
          Text(AppText.tx('ЯЗЫК И ИНТЕРФЕЙС', 'LANGUAGE & INTERFACE'), style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppText.tx('Язык приложения', 'App language'), style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings.language,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.language)),
              items: const [
                DropdownMenuItem(value: 'ru', child: Text(AppText.tx('Русский', 'Russian'))),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) { if (value != null) settings.setLanguage(value); },
            ),
            const SizedBox(height: 6),
            Text(AppText.tx('Язык системных элементов и календарных диалогов изменится сразу. Перевод остальных экранов будет расширяться в следующих обновлениях.', 'System elements and calendar dialogs update immediately. The rest of the app is being localized.'), style: TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
          const SizedBox(height: 22),
          Text(AppText.tx('ВНЕШНИЙ ВИД', 'APPEARANCE'), style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppText.tx('Цвет интерфейса', 'Accent color'), style: TextStyle(fontWeight: FontWeight.w600)),
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
            Text(AppText.tx('Фон приложения', 'App background'), style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choice(context, 'midnight', AppText.tx('Тёмно-фиолетовый', 'Midnight violet'), settings.background, (v) => settings.setBackground(v)),
            _choice(context, 'black', AppText.tx('Чёрный OLED', 'OLED black'), settings.background, (v) => settings.setBackground(v)),
            _choice(context, 'navy', AppText.tx('Тёмно-синий', 'Deep navy'), settings.background, (v) => settings.setBackground(v)),
            _choice(context, 'forest', AppText.tx('Тёмно-зелёный', 'Deep forest'), settings.background, (v) => settings.setBackground(v)),
            const Divider(height: 28, color: Colors.white12),
            Text(AppText.tx('Шрифт', 'Font'), style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _choice(context, 'system', AppText.tx('Стандартный', 'System'), settings.font, (v) => settings.setFont(v)),
            _choice(context, 'serif', AppText.tx('С засечками', 'Serif'), settings.font, (v) => settings.setFont(v)),
            _choice(context, 'mono', AppText.tx('Моноширинный', 'Monospace'), settings.font, (v) => settings.setFont(v)),
            const Divider(height: 28, color: Colors.white12),
            Row(children: [
              const Expanded(child: Text(AppText.tx('Размер текста', 'Text size'), style: TextStyle(fontWeight: FontWeight.w600))),
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
          Text(AppText.tx('АККАУНТ', 'ACCOUNT'), style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _section(child: Column(children: [
            _accountRow(Icons.mail_outline, AppText.tx('Электронная почта', 'Email address'), user?.email ?? AppText.tx('Не подключена', 'Not connected')),
            const Divider(height: 22, color: Colors.white12),
            _accountRow(Icons.security_outlined, AppText.tx('Безопасность', 'Security'), user?.emailVerified == true ? AppText.tx('Почта подтверждена', 'Email verified') : AppText.tx('Почта не подтверждена', 'Email not verified')),
            const Divider(height: 22, color: Colors.white12),
            _accountRow(Icons.info_outline, AppText.tx('Версия приложения', 'App version'), 'NEXSUS 0.1.0'),
          ])),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(AppText.tx('Выйти из аккаунта?', 'Sign out of your account?')),
                  content: Text(AppText.tx('Для следующего входа потребуется снова ввести почту и пароль.', 'You will need to enter your email and password next time.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(AppText.tx('Отмена', 'Cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(AppText.tx('Выйти', 'Sign out'))),
                  ],
                ),
              );
              if (confirmed == true) await onSignOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(AppText.tx('Выйти из аккаунта', 'Sign out')),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF858D), side: const BorderSide(color: Color(0x66FF858D)), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 14),
          Text(AppText.tx('Настройки внешнего вида сохраняются на этом устройстве.', 'Appearance settings are saved on this device.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .48), fontSize: 11)),
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
