import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

String? _pickPortugueseLocale(List<LocaleName> locales) {
  for (final l in locales) {
    if (l.localeId.toLowerCase().startsWith('pt')) return l.localeId;
  }
  return null;
}

/// Campo de texto com botão de microfone: converte fala em texto (Windows, Android, iOS).
class VoiceDictationTextField extends StatefulWidget {
  const VoiceDictationTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.maxLines = 3,
    this.minLines,
  });

  final TextEditingController controller;
  final String labelText;
  final int maxLines;
  final int? minLines;

  @override
  State<VoiceDictationTextField> createState() => _VoiceDictationTextFieldState();
}

class _VoiceDictationTextFieldState extends State<VoiceDictationTextField> {
  static final SpeechToText _speech = SpeechToText();

  bool _initAttempted = false;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _disposed = false;
  String _utteranceBase = '';

  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// No Windows o ícone no canto de campos altos passa despercebido — barra dedicada.
  bool get _windowsMicToolbar =>
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _disposed = true;
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (_initAttempted) return;
    _initAttempted = true;
    if (!_platformSupported) return;
    _speechAvailable = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
  }

  void _attachSessionListeners() {
    _speech.errorListener = (SpeechRecognitionError e) {
      if (_disposed || !mounted) return;
      setState(() => _listening = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Reconhecimento de voz: ${e.errorMsg}')),
      );
    };
    _speech.statusListener = (String status) {
      if (_disposed || !mounted) return;
      if (status == SpeechToText.notListeningStatus ||
          status == SpeechToText.doneStatus) {
        setState(() => _listening = false);
      } else if (status == SpeechToText.listeningStatus) {
        setState(() => _listening = true);
      }
    };
  }

  Future<void> _toggleListen() async {
    await _ensureInitialized();
    if (!_platformSupported || !_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reconhecimento de voz não disponível. No Windows, ative o microfone e instale o pacote de idioma português em Definições → Hora e idioma → Idioma.',
            ),
          ),
        );
      }
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _utteranceBase = widget.controller.text;
    if (_utteranceBase.isNotEmpty &&
        !_utteranceBase.endsWith(' ') &&
        !_utteranceBase.endsWith('\n')) {
      _utteranceBase = '$_utteranceBase ';
    }

    String? localeId;
    try {
      final list = await _speech.locales();
      localeId = _pickPortugueseLocale(list);
    } catch (_) {}
    localeId ??= (await _speech.systemLocale())?.localeId;

    _attachSessionListeners();

    if (mounted) setState(() => _listening = true);

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (_disposed || !mounted) return;
          final combined = _utteranceBase + result.recognizedWords;
          widget.controller.value = TextEditingValue(
            text: combined,
            selection: TextSelection.collapsed(offset: combined.length),
          );
          setState(() {});
        },
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(minutes: 2),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível iniciar o microfone: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_platformSupported) {
      return TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
        ),
        maxLines: widget.maxLines,
        minLines: widget.minLines,
      );
    }

    final field = TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
        suffixIcon: _windowsMicToolbar
            ? null
            : IconButton(
                tooltip: _listening ? 'Parar ditado' : 'Falar para escrever',
                onPressed: _toggleListen,
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none_outlined,
                  color: _listening ? Colors.red : const Color(0xFF1A237E),
                ),
              ),
      ),
      maxLines: widget.maxLines,
      minLines: widget.minLines,
    );

    if (!_windowsMicToolbar) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E),
              ),
              onPressed: _toggleListen,
              icon: Icon(
                _listening ? Icons.stop_circle_outlined : Icons.mic_none_outlined,
                color: _listening ? Colors.red : const Color(0xFF1A237E),
              ),
              label: Text(_listening ? 'Parar ditado' : 'Falar para escrever'),
            ),
            Text(
              'Converte a tua voz em texto (reconhecimento do Windows).',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }
}
