import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/journal_note.dart';
import '../models/note_recording_holder.dart';

/// Upload e remoção de ficheiros de voz das notas (Firebase Storage).
class NoteRecordingStorage {
  NoteRecordingStorage._();

  static final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  static Future<void> tryDeleteDownloadUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (e, st) {
      debugPrint('TG_Work: falha ao apagar gravação: $e\n$st');
    }
  }

  /// Devolve o URL final da nota após upload/remoção e limpa ficheiros temporários.
  static Future<String?> resolveOnSave({
    required NoteRecordingHolder holder,
    required Future<String> Function(File file) uploadPending,
  }) async {
    if (holder.deleteRecording) {
      await tryDeleteDownloadUrl(holder.originalUrl);
      final pending = holder.pendingLocalPath;
      if (pending != null) {
        final f = File(pending);
        if (await f.exists()) await f.delete();
      }
      return null;
    }
    if (holder.pendingLocalPath != null) {
      final file = File(holder.pendingLocalPath!);
      if (!await file.exists()) return holder.originalUrl;
      await tryDeleteDownloadUrl(holder.originalUrl);
      try {
        return await uploadPending(file);
      } finally {
        if (await file.exists()) await file.delete();
      }
    }
    return holder.originalUrl;
  }

  static Future<String> uploadProjectNote(String projectId, File file) async {
    final name = '${_uuid.v4()}.wav';
    final ref = _storage.ref('note_recordings/projects/$projectId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  static Future<String> uploadThemeNote(String themeId, File file) async {
    final name = '${_uuid.v4()}.wav';
    final ref = _storage.ref('note_recordings/themes/$themeId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  static Future<String> uploadDevelopmentNote(String developmentId, File file) async {
    final name = '${_uuid.v4()}.wav';
    final ref = _storage.ref('note_recordings/developments/$developmentId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Áudio anexado a uma nota do diário (`projects|themes|developments/{id}/notes/{noteId}`).
  static Future<String> uploadJournalNoteRecording({
    required JournalNoteParent parent,
    required String parentId,
    required String noteId,
    required File file,
  }) async {
    final seg = parent.firestoreSegment;
    final name = '${_uuid.v4()}.wav';
    final ref = _storage.ref('note_journal/$seg/$parentId/$noteId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
