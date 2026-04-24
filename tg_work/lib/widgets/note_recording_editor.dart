import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/note_recording_holder.dart';

/// Gravar / ouvir / remover gravação de voz da nota (Windows, Android, iOS).
class NoteRecordingEditor extends StatefulWidget {
  const NoteRecordingEditor({
    super.key,
    required this.holder,
    required this.onChanged,
  });

  final NoteRecordingHolder holder;
  final VoidCallback onChanged;

  @override
  State<NoteRecordingEditor> createState() => _NoteRecordingEditorState();
}

class _NoteRecordingEditorState extends State<NoteRecordingEditor> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  bool _recording = false;
  bool _playing = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  void dispose() {
    if (_recording) {
      _recorder.cancel();
    }
    unawaited(_playerStateSub?.cancel());
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _deletePendingFile() async {
    final path = widget.holder.pendingLocalPath;
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  Future<({RecordConfig config, String ext})> _pickFormat() async {
    if (await _recorder.isEncoderSupported(AudioEncoder.wav)) {
      return (config: const RecordConfig(encoder: AudioEncoder.wav), ext: 'wav');
    }
    if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      return (config: const RecordConfig(encoder: AudioEncoder.aacLc), ext: 'm4a');
    }
    return (config: const RecordConfig(encoder: AudioEncoder.wav), ext: 'wav');
  }

  Future<void> _startRecord() async {
    if (!_supported) return;
    final ok = await _recorder.hasPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de microfone necessária para gravar.')),
        );
      }
      return;
    }
    await _deletePendingFile();
    widget.holder.pendingLocalPath = null;
    widget.holder.deleteRecording = false;
    widget.onChanged();

    final dir = await getTemporaryDirectory();
    final fmt = await _pickFormat();
    final outPath = p.join(dir.path, 'tg_note_${DateTime.now().millisecondsSinceEpoch}.${fmt.ext}');

    try {
      await _recorder.start(fmt.config, path: outPath);
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível gravar: $e')),
        );
      }
    }
  }

  Future<void> _stopRecord() async {
    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        widget.holder.pendingLocalPath = path;
        widget.holder.deleteRecording = false;
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _playPreview() async {
    final local = widget.holder.pendingLocalPath;
    final remote = widget.holder.originalUrl;
    if (widget.holder.deleteRecording) return;

    try {
      await _playerStateSub?.cancel();
      if (local != null && await File(local).exists()) {
        await _player.setFilePath(local);
      } else if (remote != null && remote.isNotEmpty) {
        await _player.setUrl(remote);
      } else {
        return;
      }
      setState(() => _playing = true);
      _playerStateSub = _player.playerStateStream.listen((s) {
        if (!s.playing && mounted) {
          setState(() => _playing = false);
        }
      });
      await _player.play();
    } catch (e) {
      if (mounted) {
        setState(() => _playing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na reprodução: $e')),
        );
      }
    }
  }

  Future<void> _stopPlay() async {
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  void _removeRecording() {
    widget.holder.deleteRecording = true;
    unawaited(_deletePendingFile());
    widget.holder.pendingLocalPath = null;
    unawaited(_stopPlay());
    widget.onChanged();
    setState(() {});
  }

  void _undoRemove() {
    widget.holder.deleteRecording = false;
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const SizedBox.shrink();
    }

    final h = widget.holder;
    final hasServer = h.originalUrl != null && h.originalUrl!.isNotEmpty;
    final hasPending = h.pendingLocalPath != null;
    final canPlay = !_recording && !h.deleteRecording && (hasPending || hasServer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gravação de nota (voz)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!_recording)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                ),
                onPressed: _startRecord,
                icon: const Icon(Icons.fiber_manual_record, size: 18, color: Colors.red),
                label: const Text('Gravar'),
              )
            else
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                ),
                onPressed: _stopRecord,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Parar'),
              ),
            if (canPlay)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFF1A237E),
                ),
                onPressed: _playing ? _stopPlay : _playPreview,
                icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                label: Text(_playing ? 'Parar som' : 'Ouvir'),
              ),
            if (!_recording && (hasServer || hasPending))
              TextButton.icon(
                onPressed: h.deleteRecording ? _undoRemove : _removeRecording,
                icon: Icon(h.deleteRecording ? Icons.undo : Icons.delete_outline),
                label: Text(h.deleteRecording ? 'Repor gravação' : 'Remover gravação'),
              ),
          ],
        ),
        if (hasPending && !h.deleteRecording)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Nova gravação — será enviada ao guardar.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        if (h.deleteRecording)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'A gravação será removida ao guardar.',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
        if (hasServer && !hasPending && !h.deleteRecording)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Existe uma gravação guardada. Pode ouvir, substituir ou remover.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}
