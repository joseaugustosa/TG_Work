import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'note_recording_storage.dart';
import '../utils/user_display.dart';
import '../utils/entity_change_summary.dart';
import '../models/project.dart';
import '../models/theme_item.dart';
import '../models/development.dart';
import '../models/journal_note.dart';
import '../models/status_change.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static void _patchDescriptionRecordingUrl(
    Map<String, dynamic> map,
    String? oldUrl,
    String? newUrl,
  ) {
    if (oldUrl == newUrl) return;
    if (newUrl == null) {
      map['descriptionRecordingUrl'] = FieldValue.delete();
    } else {
      map['descriptionRecordingUrl'] = newUrl;
    }
  }

  // ─── Projects ────────────────────────────────────────────────────────────

  Stream<List<Project>> getProjects() {
    return _db
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Project.fromMap(d.data(), d.id)).toList());
  }

  Future<String> addProject(
    Project project, {
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    final ref = await _db.collection('projects').add(project.toMap());
    await _logAuditEntry(
      entityType: 'project',
      entityId: ref.id,
      entityName: project.name,
      summaryLine: 'Criação do projeto',
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
    return ref.id;
  }

  Future<void> updateProject(
    Project project, {
    required Project oldProject,
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    final updated = Project(
      id: project.id,
      name: project.name,
      description: project.description,
      descriptionRecordingUrl: project.descriptionRecordingUrl,
      status: project.status,
      createdBy: project.createdBy,
      createdByName: project.createdByName,
      createdAt: project.createdAt,
      updatedBy: userId,
      updatedByName: actorName,
      updatedAt: now,
    );

    final map = updated.toMap();
    _patchDescriptionRecordingUrl(
      map,
      oldProject.descriptionRecordingUrl,
      updated.descriptionRecordingUrl,
    );
    await _db.collection('projects').doc(project.id).update(map);

    final summary =
        summarizeProjectEdit(oldProject, project) ?? 'Alteração: gravação registada';
    await _logAuditEntry(
      entityType: 'project',
      entityId: project.id,
      entityName: project.name,
      summaryLine: summary,
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
  }

  Future<void> deleteProject(String projectId) async {
    await _deleteAllJournalNotes(JournalNoteParent.project, projectId);
    final snap = await _db.collection('projects').doc(projectId).get();
    final url = snap.data()?['descriptionRecordingUrl'] as String?;
    await NoteRecordingStorage.tryDeleteDownloadUrl(url);
    await _db.collection('projects').doc(projectId).delete();
  }

  Stream<Project?> watchProject(String id) {
    return _db.collection('projects').doc(id).snapshots().map(
          (doc) => doc.exists ? Project.fromMap(doc.data()!, doc.id) : null,
        );
  }

  // ─── Themes ──────────────────────────────────────────────────────────────

  Stream<List<ThemeItem>> getThemes(String projectId) {
    return _db
        .collection('themes')
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map((d) => ThemeItem.fromMap(d.data(), d.id)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<String> addTheme(
    ThemeItem theme, {
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    final ref = await _db.collection('themes').add(theme.toMap());
    await _logAuditEntry(
      entityType: 'theme',
      entityId: ref.id,
      entityName: theme.name,
      summaryLine: 'Criação do tema',
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
    return ref.id;
  }

  Future<void> updateTheme(
    ThemeItem theme, {
    required ThemeItem oldTheme,
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    final updated = ThemeItem(
      id: theme.id,
      name: theme.name,
      description: theme.description,
      descriptionRecordingUrl: theme.descriptionRecordingUrl,
      status: theme.status,
      projectId: theme.projectId,
      createdBy: theme.createdBy,
      createdByName: theme.createdByName,
      createdAt: theme.createdAt,
      updatedBy: userId,
      updatedByName: actorName,
      updatedAt: now,
    );

    final map = updated.toMap();
    _patchDescriptionRecordingUrl(
      map,
      oldTheme.descriptionRecordingUrl,
      updated.descriptionRecordingUrl,
    );
    await _db.collection('themes').doc(theme.id).update(map);

    final summary =
        summarizeThemeEdit(oldTheme, theme) ?? 'Alteração: gravação registada';
    await _logAuditEntry(
      entityType: 'theme',
      entityId: theme.id,
      entityName: theme.name,
      summaryLine: summary,
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
  }

  Future<void> deleteTheme(String themeId) async {
    await _deleteAllJournalNotes(JournalNoteParent.theme, themeId);
    final snap = await _db.collection('themes').doc(themeId).get();
    final url = snap.data()?['descriptionRecordingUrl'] as String?;
    await NoteRecordingStorage.tryDeleteDownloadUrl(url);
    await _db.collection('themes').doc(themeId).delete();
  }

  Stream<ThemeItem?> watchTheme(String id) {
    return _db.collection('themes').doc(id).snapshots().map(
          (doc) => doc.exists ? ThemeItem.fromMap(doc.data()!, doc.id) : null,
        );
  }

  // ─── Developments ─────────────────────────────────────────────────────────

  Stream<List<Development>> getDevelopments(String themeId) {
    return _db
        .collection('developments')
        .where('themeId', isEqualTo: themeId)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map((d) => Development.fromMap(d.data(), d.id)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<String> addDevelopment(
    Development dev, {
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    final ref = await _db.collection('developments').add(dev.toMap());
    await _logAuditEntry(
      entityType: 'development',
      entityId: ref.id,
      entityName: dev.name,
      summaryLine: 'Criação do desenvolvimento',
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
    return ref.id;
  }

  Future<void> updateDevelopment(
    Development dev, {
    required Development oldDev,
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    final updated = Development(
      id: dev.id,
      name: dev.name,
      description: dev.description,
      descriptionRecordingUrl: dev.descriptionRecordingUrl,
      status: dev.status,
      themeId: dev.themeId,
      projectId: dev.projectId,
      createdBy: dev.createdBy,
      createdByName: dev.createdByName,
      createdAt: dev.createdAt,
      updatedBy: userId,
      updatedByName: actorName,
      updatedAt: now,
    );

    final map = updated.toMap();
    _patchDescriptionRecordingUrl(
      map,
      oldDev.descriptionRecordingUrl,
      updated.descriptionRecordingUrl,
    );
    await _db.collection('developments').doc(dev.id).update(map);

    final summary =
        summarizeDevelopmentEdit(oldDev, dev) ?? 'Alteração: gravação registada';
    await _logAuditEntry(
      entityType: 'development',
      entityId: dev.id,
      entityName: dev.name,
      summaryLine: summary,
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
  }

  Future<void> deleteDevelopment(String devId) async {
    await _deleteAllJournalNotes(JournalNoteParent.development, devId);
    final snap = await _db.collection('developments').doc(devId).get();
    final url = snap.data()?['descriptionRecordingUrl'] as String?;
    await NoteRecordingStorage.tryDeleteDownloadUrl(url);
    await _db.collection('developments').doc(devId).delete();
  }

  Stream<Development?> watchDevelopment(String id) {
    return _db.collection('developments').doc(id).snapshots().map(
          (doc) => doc.exists ? Development.fromMap(doc.data()!, doc.id) : null,
        );
  }

  // ─── Notas do diário (subcoleção `notes`) ───────────────────────────────

  CollectionReference<Map<String, dynamic>> _journalNotesRef(
    JournalNoteParent parent,
    String parentId,
  ) {
    return _db
        .collection(parent.firestoreSegment)
        .doc(parentId)
        .collection('notes');
  }

  Future<void> _deleteAllJournalNotes(JournalNoteParent parent, String parentId) async {
    final snap = await _journalNotesRef(parent, parentId).get();
    for (final d in snap.docs) {
      final url = d.data()['recordingUrl'] as String?;
      await NoteRecordingStorage.tryDeleteDownloadUrl(url);
      await d.reference.delete();
    }
  }

  /// Sem `orderBy` na query: evita falhas por índice em subcoleções e replica o padrão do histórico.
  Stream<List<JournalNote>> watchJournalNotes(
    JournalNoteParent parent,
    String parentId,
  ) {
    return _journalNotesRef(parent, parentId).snapshots().map((s) {
      final list =
          s.docs.map((d) => JournalNote.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> addJournalNote(
    JournalNoteParent parent,
    String parentId,
    JournalNote note,
  ) async {
    final ref = await _journalNotesRef(parent, parentId).add(note.toCreateMap());
    return ref.id;
  }

  Future<void> updateJournalNoteRecording({
    required JournalNoteParent parent,
    required String parentId,
    required String noteId,
    required String recordingUrl,
  }) async {
    await _journalNotesRef(parent, parentId).doc(noteId).update({
      'recordingUrl': recordingUrl,
    });
  }

  Future<void> deleteJournalNote(
    JournalNoteParent parent,
    String parentId,
    String noteId,
  ) async {
    final doc = await _journalNotesRef(parent, parentId).doc(noteId).get();
    final url = doc.data()?['recordingUrl'] as String?;
    await NoteRecordingStorage.tryDeleteDownloadUrl(url);
    await _journalNotesRef(parent, parentId).doc(noteId).delete();
  }

  // ─── Histórico (coleção `status_changes`) ───────────────────────────────

  /// Histórico por entidade. Ordenação em memória para não exigir índice composto
  /// Firestore (`where` + `orderBy` em campos diferentes falha sem índice).
  Stream<List<StatusChange>> getStatusHistory(String entityId) {
    final id = entityId.trim();
    return _db
        .collection('status_changes')
        .where('entityId', isEqualTo: id)
        .snapshots()
        .map((snap) {
      final list = <StatusChange>[];
      for (final d in snap.docs) {
        try {
          list.add(StatusChange.fromMap(d.data(), d.id));
        } catch (e, st) {
          debugPrint('TG_Work: ignorado doc status_changes/${d.id}: $e\n$st');
        }
      }
      list.sort((a, b) => b.changedAt.compareTo(a.changedAt));
      return list;
    });
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<void> _logAuditEntry({
    required String entityType,
    required String entityId,
    required String entityName,
    required String summaryLine,
    required String userId,
    required String userName,
    required DateTime changedAt,
  }) async {
    final actor = normalizeStoredActorName(userName);
    final eid = entityId.trim();
    final entry = StatusChange(
      id: '',
      entityType: entityType,
      entityId: eid,
      entityName: entityName,
      kind: 'audit',
      summaryLine: summaryLine,
      oldStatusKey: '',
      oldStatusLabel: '',
      newStatusKey: '',
      newStatusLabel: '',
      changedBy: userId,
      changedByName: actor,
      changedAt: changedAt,
    );
    try {
      await _db.collection('status_changes').add(entry.toMap());
    } catch (e, st) {
      // O projeto/tema/desenvolvimento já foi gravado; o histórico falhou (ex.: regras).
      debugPrint('TG_Work: falha ao gravar histórico: $e\n$st');
    }
  }
}
