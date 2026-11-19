import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class JarvisScreen extends StatefulWidget {
  const JarvisScreen({super.key, required this.nickname});
  final String nickname;

  @override
  State<JarvisScreen> createState() => _JarvisScreenState();
}

class _JarvisScreenState extends State<JarvisScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _speechReady = false;
  bool _listening = false;
  bool _busy = false;
  bool _speaking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _messages.add({
      'role': 'assistant',
      'content': 'Привет, ${widget.nickname}! Я Джарвис. Нажми на микрофон и скажи, чем помочь.',
    });
  }

  Future<void> _initializeVoice() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (mounted) setState(() {
            _listening = false;
            _error = 'Не удалось распознать речь. Проверь разрешение микрофона.';
          });
        },
      );
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(0.95);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'Голосовые функции недоступны на этом устройстве.');
    }
  }

  Future<void> _toggleListening() async {
    if (_busy) return;
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (!_speechReady) await _initializeVoice();
    if (!_speechReady) {
      setState(() => _error = 'Распознавание речи не поддерживается. Можно написать сообщение ниже.');
      return;
    }
    setState(() => _error = null);
    await _tts.stop();
    await _speech.listen(
      localeId: 'ru_RU',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _input.text = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          _send(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _send([String? voiceText]) async {
    final text = (voiceText ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _error = null;
      _busy = true;
      _messages.add({'role': 'user', 'content': text});
    });
    _scrollToBottom();
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'askJarvis',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final recent = _messages.where((m) => m['role'] != 'system').toList();
      final result = await callable.call({
        'messages': recent.length > 16 ? recent.sublist(recent.length - 16) : recent,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = (data['reply'] ?? '').toString().trim();
      if (answer.isEmpty) throw Exception('Пустой ответ сервера');
      if (!mounted) return;
      setState(() => _messages.add({'role': 'assistant', 'content': answer}));
      _scrollToBottom();
      _speaking = true;
      await _tts.speak(answer);
      _speaking = false;
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = switch (e.code) {
        'unauthenticated' => 'Сначала войди в аккаунт NEXSUS.',
        'failed-precondition' => 'Сервер Джарвиса ещё не настроен: нужен защищённый ключ Groq.',
        'resource-exhausted' => 'Достигнут временный лимит запросов. Попробуй позже.',
        _ => 'Не удалось связаться с Джарвисом. Проверь интернет и настройку сервера.',
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось получить ответ. Сервер Groq ещё может быть не подключён.');
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _speaking = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF8C4DFF), Color(0xFF236BFF)]),
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ДЖАРВИС', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('Голосовой ИИ-помощник', style: TextStyle(fontSize: 11, color: Colors.white60)),
          ])),
          Icon(Icons.circle, size: 8, color: _busy ? Colors.orangeAccent : const Color(0xFF36D9A0)),
          const SizedBox(width: 6),
          Text(_busy ? 'ДУМАЮ' : 'ГОТОВ', style: const TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.white60)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          itemCount: _messages.length + (_busy ? 1 : 0),
          itemBuilder: (context, index) {
            if (_busy && index == _messages.length) {
              return const Align(alignment: Alignment.centerLeft, child: Padding(
                padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }
            final message = _messages[index];
            final isUser = message['role'] == 'user';
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 310),
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF49318A) : const Color(0xFF171832),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF7650D8).withValues(alpha: .28)),
                ),
                child: Text(message['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
            );
          },
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Row(children: [
          IconButton(
            onPressed: _toggleListening,
            iconSize: 27,
            color: _listening ? Colors.redAccent : const Color(0xFFB99AFF),
            icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
            tooltip: _listening ? 'Остановить запись' : 'Говорить',
          ),
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _listening ? 'Слушаю тебя…' : 'Напиши Джарвису…',
                filled: true,
                fillColor: const Color(0xFF171832),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _busy ? null : () => _send(),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF7549E8)),
            icon: const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    ]);
  }
}
