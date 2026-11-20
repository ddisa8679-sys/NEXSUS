import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'app_text.dart';

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
  StreamSubscription<User?>? _authSubscription;
  bool _navigated = false;

  void _openUser(User user) {
    if (!mounted || _navigated) return;
    _navigated = true;
    final nickname = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'NEXSUS');
    widget.onAuthenticated(context, nickname);
  }

  @override
  void initState() {
    super.initState();
    if (widget.firebaseReady) {
      _authSubscription = _auth.authStateChanges.listen((user) {
        if (user != null) _openUser(user);
      });
      final user = _auth.currentUser;
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openUser(user));
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    if (!widget.firebaseReady) {
      _message(AppText.tx('Firebase не настроен. Добавь google-services.json и настрой Android-приложение.', 'Firebase is not configured. Add google-services.json and configure the Android app.'));
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
        if (mounted) { _navigated = true; widget.onAuthenticated(context, nickname); }
      } else {
        final credential = await _auth.signIn(email: _email.text, password: _password.text);
        final nickname = credential.user?.displayName?.trim().isNotEmpty == true
            ? credential.user!.displayName!.trim()
            : (_email.text.trim().split('@').first);
        if (mounted) { _navigated = true; widget.onAuthenticated(context, nickname); }
      }
    } on FirebaseAuthException catch (e) {
      _message(_authError(e.code));
    } catch (_) {
      _message(AppText.tx('Firebase ещё не настроен. Добавь конфигурацию Android и повтори попытку.', 'Firebase is not configured yet. Check the Android configuration and try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _authError(String code) => switch (code) {
    'invalid-email' => AppText.tx('Некорректный адрес почты.', 'Invalid email address.'),
    'user-disabled' => AppText.tx('Этот аккаунт отключён.', 'This account has been disabled.'),
    'user-not-found' || 'wrong-password' || 'invalid-credential' => AppText.tx('Неверная почта или пароль.', 'Incorrect email or password.'),
    'email-already-in-use' => AppText.tx('Аккаунт с такой почтой уже существует.', 'An account with this email already exists.'),
    'weak-password' => AppText.tx('Пароль слишком простой.', 'Password is too weak.'),
    'too-many-requests' => AppText.tx('Слишком много попыток. Попробуй позже.', 'Too many attempts. Try again later.'),
    'network-request-failed' => AppText.tx('Нет подключения к интернету.', 'No internet connection.'),
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
                    Container(
                      width: 86, height: 86,
                      margin: const EdgeInsets.symmetric(horizontal: 110),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7650D8), Color(0xFF17132E)]),
                        border: Border.all(color: const Color(0xFFFFD27A), width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0x557650D8), blurRadius: 28, spreadRadius: 3)],
                      ),
                      child: const Center(child: Text('N', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Color(0xFFFFD27A), fontFamily: 'serif', height: 1))),
                    ),
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
                        Text(_register ? AppText.tx('Создать аккаунт', 'Create account') : AppText.tx('С возвращением', 'Welcome back'),
                          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 7),
                        Text(_register ? AppText.tx('Заполни данные для нового профиля', 'Set up your new profile') : AppText.tx('Войди в своё пространство NEXSUS', 'Sign in to your NEXSUS space'),
                          style: const TextStyle(color: Colors.white60)),
                        const SizedBox(height: 24),
                        _field(_email, AppText.tx('Электронная почта', 'Email address'), Icons.mail_outline,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? AppText.tx('Укажи корректную почту', 'Enter a valid email address') : null),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          _field(_nickname, AppText.tx('Никнейм', 'Display name'), Icons.badge_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? AppText.tx('Придумай никнейм', 'Choose a display name') : null),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          validator: (v) => (v == null || v.length < 6) ? AppText.tx('Минимум 6 символов', 'At least 6 characters') : null,
                          decoration: _decoration(AppText.tx('Пароль', 'Password'), Icons.lock_outline).copyWith(
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
                            child: Text(AppText.tx('Забыл пароль?', 'Forgot password?')),
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
                          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_register ? AppText.tx('ЗАРЕГИСТРИРОВАТЬСЯ', 'CREATE ACCOUNT') : AppText.tx('ВОЙТИ', 'SIGN IN'),
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _register = !_register),
                          child: Text(_register ? AppText.tx('Уже есть аккаунт? Войти', 'Already have an account? Sign in') : AppText.tx('Нет аккаунта? Создать', 'New here? Create an account')),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    Text(AppText.tx('ЗАЩИЩЁННОЕ ЛИЧНОЕ ПРОСТРАНСТВО', 'YOUR PRIVATE DIGITAL SPACE'),
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
      title: Text(AppText.tx('Восстановление пароля', 'Password recovery')),
      content: Text(AppText.tx('На указанный адрес будет отправлена ссылка для сброса пароля.', 'A password reset link will be sent to your email address.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(AppText.tx('Отмена', 'Cancel'))),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          if (!widget.firebaseReady) {
            _message(AppText.tx('Firebase не настроен. Добавь google-services.json и настрой Android-приложение.', 'Firebase is not configured. Add google-services.json and configure the Android app.'));
            return;
          }
          if (!_email.text.contains('@')) {
            _message(AppText.tx('Сначала введи корректный адрес почты.', 'Enter a valid email address first.'));
            return;
          }
          try {
            await _auth.sendPasswordReset(_email.text);
            _message(AppText.tx('Ссылка для сброса пароля отправлена на почту.', 'Password reset link sent.'));
          } on FirebaseAuthException catch (e) {
            _message(_authError(e.code));
          } catch (_) {
            _message('Firebase ещё не настроен. Проверь конфигурацию Android.');
          }
        }, child: Text(AppText.tx('Отправить', 'Send'))),
      ],
    ));
  }
}
