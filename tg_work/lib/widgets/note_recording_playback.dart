import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Reproduz a gravação da nota (URL no Storage).
class NoteRecordingPlayback extends StatefulWidget {
  const NoteRecordingPlayback({super.key, this.downloadUrl});

  final String? downloadUrl;

  @override
  State<NoteRecordingPlayback> createState() => _NoteRecordingPlaybackState();
}

class _NoteRecordingPlaybackState extends State<NoteRecordingPlayback> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _playing = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.downloadUrl;
    if (url == null || url.isEmpty) return;

    if (_playing) {
      await _sub?.cancel();
      _sub = null;
      await _player.stop();
      setState(() => _playing = false);
      return;
    }

    try {
      await _sub?.cancel();
      await _player.setUrl(url);
      setState(() => _playing = true);
      _sub = _player.playerStateStream.listen((s) {
        if (!s.playing && mounted) setState(() => _playing = false);
      });
      await _player.play();
    } catch (e) {
      if (mounted) {
        setState(() => _playing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reproduzir gravação: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.downloadUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.mic, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gravação de nota',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
          TextButton.icon(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
            label: Text(_playing ? 'Parar' : 'Ouvir'),
          ),
        ],
      ),
    );
  }
}
