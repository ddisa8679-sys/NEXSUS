import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_text.dart';

class JarvisScreen extends StatefulWidget {
  const JarvisScreen({super.key, required this.nickname});
  final String nickname;

  @override
  State<JarvisScreen> createState() => _JarvisScreenState();
}

class _JarvisScreenState extends State<JarvisScreen> {
  static const String _modelUrl =
      'https://huggingface.co/tensorblock/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf?download=true';
  static const int _expectedModelBytes = 484000000;
  static const String _historyKey = 'nexsus_jarvis_history_v1';

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  final LlamaController _llama = LlamaController();

  bool _speechReady = false;
  bool _listening = false;
  bool _busy = false;
  bool _modelReady = false;
  bool _downloading = false;
  bool _speaking = false;
  double _downloadProgress = 0;
  String _status = AppText.tx('Подготовка локального ИИ…', 'Preparing local AI…');
  String? _error;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content': AppText.tx('Привет, ${widget.nickname}! Я Джарвис. Сейчас подготовлю локальный ИИ. После загрузки модели смогу отвечать без интернета.', 'Hello, ${widget.nickname}! I am Jarvis. I am preparing the local AI. Once the model is downloaded, I can answer offline.'),
    });
    _loadConversation();
    _initializeVoice();
    _prepareModel();
  }

  Future<void> _loadConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final restored = decoded
          .whereType<Map>()
          .map((item) => Map<String, String>.from(item))
          .where((item) =>
              (item['role'] == 'user' || item['role'] == 'assistant') &&
              (item['content'] ?? '').trim().isNotEmpty)
          .toList();
      if (!mounted || restored.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(restored.take(60));
      });
      _scrollToBottom();
    } catch (_) {
      // A damaged local history must never prevent the assistant from starting.
    }
  }

  Future<void> _saveConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _messages
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .toList();
      await prefs.setString(_historyKey, jsonEncode(saved.take(60).toList()));
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppText.tx('Не удалось сохранить историю диалога на устройстве.', 'Could not save chat history on this device.'));
      }
    }
  }

  Future<void> _clearConversation() async {
    if (_busy || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.tx('Очистить историю?', 'Clear conversation?')),
        content: const Text(AppText.tx('Все сохранённые сообщения Джарвиса на этом устройстве будут удалены.', 'All saved Jarvis messages on this device will be deleted.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppText.tx('Отмена', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppText.tx('Очистить', 'Clear')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add({
          'role': 'assistant',
          'content': AppText.tx('История очищена. Начнём новый разговор?', 'History cleared. Shall we start a new conversation?'),
        });
      _error = null;
    });
    _scrollToBottom();
  }

  Future<void> _initializeVoice() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (_) {
          if (mounted) setState(() {
            _listening = false;
            _error = AppText.tx('Не удалось распознать речь. Можно написать сообщение ниже.', 'Speech not recognized. You can type a message below.');
          });
        },
      );
      await _tts.setLanguage(AppText.language == 'en' ? 'en-US' : 'ru-RU');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(0.95);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = AppText.tx('Голосовые функции недоступны на этом устройстве.', 'Voice features are unavailable on this device.'));
    }
  }

  Future<File> _modelFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/qwen3-0.6b-q4_k_m.gguf');
  }

  Future<void> _prepareModel() async {
    if (_downloading || _modelReady) return;
    setState(() {
      _downloading = true;
      _error = null;
      _status = AppText.tx('Проверяю файл модели…', 'Checking model file…');
      _downloadProgress = 0;
    });

    final model = await _modelFile();
    final partial = File('${model.path}.part');
    final client = http.Client();
    try {
      if (await model.exists() && await model.length() >= _expectedModelBytes * 0.95) {
        setState(() => _status = AppText.tx('Проверяю установленную модель…', 'Verifying installed model…'));
      } else {
        if (await model.exists()) await model.delete();
        var received = await partial.exists() ? await partial.length() : 0;
        if (received >= _expectedModelBytes) {
          await partial.delete();
          received = 0;
        }

        setState(() => _status = received > 0
            ? 'Продолжаю загрузку с ${(received / 1000000).toStringAsFixed(0)} МБ…'
            : AppText.tx('Загружаю ИИ-модель (около 484 МБ)…', 'Downloading AI model (about 484 MB)…'));

        final request = http.Request('GET', Uri.parse(_modelUrl))
          ..headers['User-Agent'] = 'NEXSUS-Android/1.0';
        if (received > 0) request.headers['Range'] = 'bytes=$received-';

        final response = await client.send(request);
        if (received > 0 && response.statusCode == 200) {
          // The host ignored Range: restart cleanly rather than corrupting the file.
          await partial.delete();
          received = 0;
        } else if (received > 0 && response.statusCode != 206) {
          throw Exception('Сервер не поддержал продолжение загрузки (HTTP ${response.statusCode}).');
        } else if (received == 0 && response.statusCode != 200 && response.statusCode != 206) {
          throw Exception('Сервер модели ответил: HTTP ${response.statusCode}.');
        }

        final total = response.contentLength == null
            ? _expectedModelBytes
            : response.contentLength! + received;
        final sink = partial.openWrite(mode: received > 0 ? FileMode.append : FileMode.write);
        try {
          var downloaded = received;
          await for (final chunk in response.stream) {
            sink.add(chunk);
            downloaded += chunk.length;
            if (mounted) {
              setState(() {
                _downloadProgress = (downloaded / total).clamp(0.0, 1.0);
                _status = 'Загружаю ИИ-модель… ${(downloaded / 1000000).toStringAsFixed(0)} МБ';
              });
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        final finalBytes = await partial.length();
        if (finalBytes < _expectedModelBytes * 0.95) {
          throw Exception('Файл получен не полностью: ${(finalBytes / 1000000).toStringAsFixed(1)} МБ. При следующей попытке загрузка продолжится.');
        }
        final header = await partial.open(mode: FileMode.read);
        final magic = await header.read(4);
        await header.close();
        if (String.fromCharCodes(magic) != 'GGUF') {
          throw Exception('Сервер вернул не GGUF-модель. Частичный файл сохранён для диагностики.');
        }
        if (await model.exists()) await model.delete();
        await partial.rename(model.path);
      }

      if (!mounted) return;
      setState(() => _status = AppText.tx('Запускаю модель на устройстве…', 'Starting the model on this device…'));
      await _llama.loadModel(
        modelPath: model.path,
        threads: 4,
        contextSize: 2048,
      );
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _status = AppText.tx('Локальный ИИ готов — интернет для ответов не нужен', 'Local AI is ready — no internet needed for answers');
        _error = null;
        _downloadProgress = 1;
      });
      if (!_messages.any((m) => m['role'] == 'user')) {
        _messages.add({
          'role': 'assistant',
          'content': 'Готово! Моя языковая модель загружена на устройство. Теперь мои текстовые ответы формируются прямо на планшете.',
        });
      }
      await _saveConversation();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = AppText.tx('Модель пока не установлена', 'Model is not installed yet');
          _error = 'Не удалось подготовить локальный ИИ: $e';
        });
      }
    } finally {
      client.close();
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_busy || !_modelReady) return;
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (!_speechReady) await _initializeVoice();
    if (!_speechReady) {
      setState(() => _error = AppText.tx('Распознавание речи недоступно. Напиши сообщение.', 'Speech recognition is unavailable. Type a message instead.'));
      return;
    }
    setState(() => _error = null);
    await _tts.stop();
    await _speech.listen(
      localeId: AppText.language == 'en' ? 'en_US' : 'ru_RU',
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
    if (!_modelReady) {
      setState(() => _error = AppText.tx('Сначала нужно загрузить локальную модель.', 'Download the local model first.'));
      return;
    }
    _input.clear();
    setState(() {
      _error = null;
      _busy = true;
      _messages.add({'role': 'user', 'content': text});
    });
    _scrollToBottom();
    await _saveConversation();
    try {
      final chat = <ChatMessage>[
        ChatMessage(
          role: 'system',
          content: AppText.tx('Ты Джарвис — дружелюбный персональный ИИ-помощник. Всегда отвечай на русском языке, понятно и по делу. Не выдумывай факты. Если не знаешь — честно скажи. Отвечай кратко, если пользователь не просит подробностей.', 'You are Jarvis, a friendly personal AI assistant. Always answer in English, clearly and directly. Do not invent facts. If you do not know, say so honestly. Be concise unless the user asks for detail.'),
        ),
        ..._messages.where((m) => m['role'] == 'user' || m['role'] == 'assistant')
            .toList()
            .take(17)
            .map((m) => ChatMessage(role: m['role']!, content: m['content']!)),
      ];
      final answer = StringBuffer();
      await for (final token in _llama.generateChat(
        messages: chat,
        template: 'chatml',
        maxTokens: 320,
        temperature: 0.7,
        topP: 0.9,
        repeatPenalty: 1.12,
      )) {
        answer.write(token);
      }
      final reply = answer.toString().trim();
      if (reply.isEmpty) throw Exception('Модель не вернула ответ');
      if (!mounted) return;
      setState(() => _messages.add({'role': 'assistant', 'content': reply}));
      await _saveConversation();
      _scrollToBottom();
      _speaking = true;
      await _tts.speak(reply);
      _speaking = false;
    } catch (e) {
      if (mounted) setState(() => _error = 'Ошибка локальной модели: $e');
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
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _llama.dispose();
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppText.tx('ДЖАРВИС', 'JARVIS'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text(AppText.tx('Локальный голосовой ИИ · память диалога', 'Local voice AI · conversation memory'), style: TextStyle(fontSize: 10, color: Colors.white60)),
          ])),
          IconButton(
            tooltip: AppText.tx('Очистить историю', 'Clear conversation'),
            onPressed: _busy ? null : _clearConversation,
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white60),
          ),
          Icon(Icons.circle, size: 8, color: _modelReady ? const Color(0xFF36D9A0) : Colors.orangeAccent),
          const SizedBox(width: 6),
          Text(_busy ? AppText.tx('ДУМАЮ', 'THINKING') : (_modelReady ? AppText.tx('ГОТОВ', 'READY') : AppText.tx('ЗАГРУЗКА', 'DOWNLOADING')),
              style: const TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.white60)),
        ]),
      ),
      if (!_modelReady)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _downloading ? _downloadProgress : null),
            if (_downloading && _downloadProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ),
            if (!_downloading && _error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _prepareModel,
                  icon: const Icon(Icons.refresh),
                  label: const Text(AppText.tx('Повторить загрузку', 'Retry download')),
                ),
              ),
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
      if (_error != null && _modelReady)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Row(children: [
          IconButton(
            onPressed: _modelReady ? _toggleListening : null,
            iconSize: 27,
            color: _listening ? Colors.redAccent : const Color(0xFFB99AFF),
            icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
            tooltip: _listening ? AppText.tx('Остановить запись', 'Stop recording') : AppText.tx('Говорить', 'Speak'),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              enabled: _modelReady && !_busy,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _modelReady ? (_listening ? AppText.tx('Слушаю тебя…', 'Listening…') : AppText.tx('Напиши Джарвису…', 'Message Jarvis…')) : AppText.tx('Загружается ИИ-модель…', 'AI model is loading…'),
                filled: true,
                fillColor: const Color(0xFF171832),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _modelReady && !_busy ? () => _send() : null,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF7549E8)),
            icon: const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    ]);
  }
}
