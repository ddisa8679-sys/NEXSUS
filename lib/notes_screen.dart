import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static const _storageKey = 'nexsus_voice_notes_v1';
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _text = TextEditingController();
  final List<String> _notes = [];
  bool _ready = false;
  bool _listening = false;
  String _status = 'Нажми на микрофон и говори — запись появится здесь';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _notes
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _notes);
  }

  Future<void> _startVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _ready = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _status = 'Не удалось распознать речь. Попробуй ещё раз или введи текст.';
        });
      },
    );

    if (!_ready) {
      if (!mounted) return;
      setState(() {
        _status = 'Голосовой ввод недоступен. Проверь разрешение микрофона и службу распознавания речи Android.';
      });
      return;
    }

    setState(() {
      _listening = true;
      _status = 'Слушаю… говори, запись сохранится после паузы';
    });

    await _speech.listen(
      localeId: 'ru_RU',
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      onResult: (result) async {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        setState(() => _text.text = words);
        if (result.finalResult && words.isNotEmpty) {
          await _addNote(words);
        }
      },
    );
  }

  Future<void> _addNote([String? spoken]) async {
    final value = (spoken ?? _text.text).trim();
    if (value.isEmpty) return;
    setState(() {
      _notes.insert(0, value);
      _text.clear();
      _status = 'Заметка сохранена';
    });
    await _saveNotes();
  }

  Future<void> _deleteNote(int index) async {
    setState(() => _notes.removeAt(index));
    await _saveNotes();
  }

  @override
  void dispose() {
    _speech.stop();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        const Text('ЗАМЕТКИ', style: TextStyle(fontSize: 12, letterSpacing: 2, color: Color(0xFFFFD27A), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Говори — NEXSUS запишет', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_status, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF211B35), Color(0xFF101426)]),
            border: Border.all(color: const Color(0x66FFD27A)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _startVoice,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? const Color(0xFF8C3345) : const Color(0xFF392B20),
                    border: Border.all(color: const Color(0xFFFFD27A), width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x55FFB84D), blurRadius: 18)],
                  ),
                  child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, size: 38, color: const Color(0xFFFFD27A)),
                ),
              ),
              const SizedBox(height: 12),
              Text(_listening ? 'ОСТАНОВИТЬ ЗАПИСЬ' : 'НАЖМИ И ГОВОРИ', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 18),
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Или напиши заметку здесь…',
                  filled: true,
                  fillColor: const Color(0xFF090D1B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addNote(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Сохранить заметку'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8C642B), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Text('МОИ ЗАМЕТКИ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4))),
            Text('${_notes.length}', style: const TextStyle(color: Color(0xFFFFD27A))),
          ],
        ),
        const SizedBox(height: 12),
        if (_notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('Пока заметок нет.\nНажми на микрофон, чтобы создать первую.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
          )
        else
          ...List.generate(_notes.length, (index) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF15182C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x332D2C4A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, color: Color(0xFFFFD27A), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_notes[index])),
                IconButton(
                  tooltip: 'Удалить заметку',
                  onPressed: () => _deleteNote(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                ),
              ],
            ),
          )),
      ],
    );
  }
}
