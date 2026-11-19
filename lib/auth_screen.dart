import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _login.dispose();
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Интерфейс готов. Для настоящего входа нужно подключить сервер авторизации.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFFB99AFF);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF09091D), Color(0xFF11143A), Color(0xFF080817)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.bolt, size: 58, color: violet),
                    const SizedBox(height: 8),
                    const Text('NEXSUS', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6)),
                    const SizedBox(height: 8),
                    const Text('ТВОЁ ЛИЧНОЕ ЦИФРОВОЕ ПРОСТРАНСТВО',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1.4)),
                    const SizedBox(height: 34),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xDD15162F),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: violet.withValues(alpha: .45)),
                        boxShadow: [BoxShadow(color: violet.withValues(alpha: .10), blurRadius: 30)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(_register ? 'Создать аккаунт' : 'С возвращением',
                          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 7),
                        Text(_register ? 'Заполни данные для нового профиля' : 'Войди в своё пространство NEXSUS',
                          style: const TextStyle(color: Colors.white60)),
                        const SizedBox(height: 24),
                        _field(_login, 'Логин', Icons.person_outline),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          _field(_nickname, 'Никнейм', Icons.badge_outlined),
                          const SizedBox(height: 14),
                          _field(_email, 'Электронная почта', Icons.mail_outline,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@')) ? 'Укажи корректную почту' : null),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          validator: (v) => (v == null || v.length < 6) ? 'Минимум 6 символов' : null,
                          decoration: _decoration('Пароль', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        if (!_register) Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgot,
                            child: const Text('Забыл пароль?'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7549E8),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(_register ? 'ЗАРЕГИСТРИРОВАТЬСЯ' : 'ВОЙТИ',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _register = !_register),
                          child: Text(_register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Создать'),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    const Text('ЗАЩИЩЁННОЕ ЛИЧНОЕ ПРОСТРАНСТВО',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Заполни поле' : null,
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFFB99AFF)),
    filled: true,
    fillColor: const Color(0xFF0B0D20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0x334F4C82))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFF9B78FF))),
  );

  void _forgot() {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Восстановление пароля'),
      content: const Text('Восстановление по коду на почту подключим вместе с серверной авторизацией.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
    ));
  }
}
