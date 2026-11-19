import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.firebaseReady, required this.onAuthenticated});
  final bool firebaseReady;
  final void Function(BuildContext context, String nickname) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;
  bool _busy = false;
  AuthService get _auth => AuthService();

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    if (!widget.firebaseReady) {
      _message('Firebase не настроен. Добавь google-services.json и настрой Android-приложение.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        final credential = await _auth.register(
          email: _email.text,
          password: _password.text,
          nickname: _nickname.text,
        );
        final nickname = credential.user?.displayName?.trim().isNotEmpty == true
            ? credential.user!.displayName!.trim()
            : _nickname.text.trim();
        if (mounted) widget.onAuthenticated(context, nickname);
      } else {
        final credential = await _auth.signIn(email: _email.text, password: _password.text);
        final nickname = credential.user?.displayName?.trim().isNotEmpty == true
            ? credential.user!.displayName!.trim()
            : (_email.text.trim().split('@').first);
        if (mounted) widget.onAuthenticated(context, nickname);
      }
    } on FirebaseAuthException catch (e) {
      _message(_authError(e.code));
    } catch (_) {
      _message('Firebase ещё не настроен. Добавь конфигурацию Android и повтори попытку.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _authError(String code) => switch (code) {
    'invalid-email' => 'Некорректный адрес почты.',
    'user-disabled' => 'Этот аккаунт отключён.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Неверная почта или пароль.',
    'email-already-in-use' => 'Аккаунт с такой почтой уже существует.',
    'weak-password' => 'Пароль слишком простой.',
    'too-many-requests' => 'Слишком много попыток. Попробуй позже.',
    'network-request-failed' => 'Нет подключения к интернету.',
    _ => 'Не удалось выполнить запрос ($code).',
  };

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
                        _field(_email, 'Электронная почта', Icons.mail_outline,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Укажи корректную почту' : null),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          _field(_nickname, 'Никнейм', Icons.badge_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Придумай никнейм' : null),
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
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7549E8),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_register ? 'ЗАРЕГИСТРИРОВАТЬСЯ' : 'ВОЙТИ',
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
      content: const Text('На указанный адрес будет отправлена ссылка для сброса пароля.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          if (!widget.firebaseReady) {
            _message('Firebase не настроен. Добавь google-services.json и настрой Android-приложение.');
            return;
          }
          if (!_email.text.contains('@')) {
            _message('Сначала введи корректный адрес почты.');
            return;
          }
          try {
            await _auth.sendPasswordReset(_email.text);
            _message('Ссылка для сброса пароля отправлена на почту.');
          } on FirebaseAuthException catch (e) {
            _message(_authError(e.code));
          } catch (_) {
            _message('Firebase ещё не настроен. Проверь конфигурацию Android.');
          }
        }, child: const Text('Отправить')),
      ],
    ));
  }
}
