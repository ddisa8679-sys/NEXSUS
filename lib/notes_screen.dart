import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_text.dart';

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
  bool _voicePressed = false;
  String _voiceDraft = '';
  String _status = AppText.tx('Зажми микрофон, говори и отпусти — заметка сохранится', 'Hold the microphone, speak, then release to save a note');

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
    _voicePressed = true;
    _voiceDraft = '';
    _text.clear();

    _ready = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'listening') {
          setState(() => _listening = true);
        } else if (status == 'notListening' || status == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _status = AppText.tx('Не удалось распознать речь. Проверь микрофон и попробуй ещё раз.', 'Speech not recognized. Check the microphone and try again.');
        });
      },
    );

    if (!_voicePressed || !mounted) return;
    if (!_ready) {
      setState(() {
        _status = AppText.tx('Голосовой ввод недоступен. Проверь разрешение микрофона и службу распознавания речи Android.', 'Voice input is unavailable. Check microphone permission and Android speech recognition.');
      });
      return;
    }

    setState(() {
      _listening = true;
      _status = AppText.tx('Слушаю… отпусти кнопку, чтобы сохранить заметку', 'Listening… release to save your note');
    });

    await _speech.listen(
      localeId: AppText.language == 'en' ? 'en_US' : 'ru_RU',
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          _voiceDraft = words;
          setState(() => _text.text = words);
        }
      },
    );
  }

  Future<void> _stopVoice() async {
    _voicePressed = false;
    if (_listening) await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);

    // Give the speech plugin a moment to deliver its final recognition result.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final words = _voiceDraft.trim().isNotEmpty ? _voiceDraft.trim() : _text.text.trim();
    if (words.isNotEmpty) {
      await _addNote(words);
    } else {
      setState(() => _status = AppText.tx('Речь не распознана. Зажми кнопку и попробуй ещё раз.', 'No speech detected. Hold the button and try again.'));
    }
  }

  Future<void> _addNote([String? spoken]) async {
    final value = (spoken ?? _text.text).trim();
    if (value.isEmpty) return;
    setState(() {
      _notes.insert(0, value);
      _text.clear();
      _status = AppText.tx('Заметка сохранена', 'Note saved');
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
        Text(AppText.tx('ЗАМЕТКИ', 'NOTES'), style: TextStyle(fontSize: 12, letterSpacing: 2, color: Color(0xFFB7A2F6), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(AppText.tx('Говори — NEXSUS запишет', 'Speak — NEXSUS will write it down'), style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_status, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF1A1C20),
            border: Border.all(color: const Color(0xFF303238)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onLongPressStart: (_) => _startVoice(),
                onLongPressEnd: (_) => _stopVoice(),
                onLongPressCancel: _stopVoice,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? const Color(0xFF8C3345) : const Color(0xFF292B31),
                    border: Border.all(color: const Color(0xFFB7A2F6), width: 2),
                    
                  ),
                  child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, size: 38, color: const Color(0xFFB7A2F6)),
                ),
              ),
              const SizedBox(height: 12),
              Text(_listening ? AppText.tx('ОТПУСТИ, ЧТОБЫ СОХРАНИТЬ', 'RELEASE TO SAVE') : AppText.tx('ЗАЖМИ И ГОВОРИ', 'HOLD AND SPEAK'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 18),
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: AppText.tx('Или напиши заметку здесь…', 'Or type a note here…'),
                  filled: true,
                  fillColor: const Color(0xFF22252A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addNote(),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(AppText.tx('Сохранить заметку', 'Save note')),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB7A2F6), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text(AppText.tx('МОИ ЗАМЕТКИ', 'MY NOTES'), style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4))),
            Text('${_notes.length}', style: const TextStyle(color: Color(0xFFB7A2F6))),
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
              color: const Color(0xFF1A1C20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF303238)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded, color: Color(0xFFB7A2F6), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(_notes[index])),
                IconButton(
                  tooltip: AppText.tx('Удалить заметку', 'Delete note'),
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
