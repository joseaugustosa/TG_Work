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
import '../models/user_billing_settings.dart';
import '../models/active_work_clock.dart';
import '../models/ide_schedule_card.dart';
import '../models/ide_schedule_lane.dart';
import '../models/ide_session_log.dart';
import '../models/ide_session_kind.dart';
import '../models/ide_project_report_snapshot.dart';
import '../utils/ide_project_session_summary.dart';
import '../utils/ide_project_report_totals.dart';
import '../utils/ide_project_auto_link.dart';

/// IDs legacy em `user_project_work`: `uid::projectId`.
/// No cliente Windows apareceram quedas ao subscrever documentos com `:` no ID.
/// Novos IDs: `uid__wk__projectId`. Migrámos cada par utilizador/projeto uma vez.
final Map<String, Future<void>> _userProjectWorkMergeFutures = {};

Future<void> _ensureUserProjectWorkIdMigratedOnce(
  FirebaseFirestore db,
  String userId,
  String projectId,
) {
  final key = '$userId|$projectId';
  return _userProjectWorkMergeFutures[key] ??=
      _mergeLegacyUserProjectWorkIntoModern(db, userId, projectId);
}

Future<void> _mergeLegacyUserProjectWorkIntoModern(
  FirebaseFirestore db,
  String userId,
  String projectId,
) async {
  final legacyRef = db.collection('user_project_work').doc('$userId::$projectId');
  final modernRef =
      db.collection('user_project_work').doc('${userId}__wk__$projectId');

  final legacySnap = await legacyRef.get();
  if (!legacySnap.exists) return;

  int readSecs(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  final legSecs = readSecs(legacySnap.data()?['totalSeconds']);
  final newSnap = await modernRef.get();
  try {
    if (!newSnap.exists) {
      if (legSecs > 0) {
        await modernRef.set(
          {
            'userId': userId,
            'projectId': projectId,
            'totalSeconds': legSecs,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } else {
      final neuSecs = readSecs(newSnap.data()?['totalSeconds']);
      final delta = legSecs - neuSecs;
      if (delta > 0) {
        await modernRef.set(
          {
            'userId': userId,
            'projectId': projectId,
            'totalSeconds': FieldValue.increment(delta),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }
    await legacyRef.delete();
  } catch (e, st) {
    debugPrint('TG_Work: migrate user_project_work $userId::$projectId -> __wk__: $e\n$st');
  }
}

/// Chama esta função antes de devolver snapshots do doc moderno para evitar dois totais dispersos.
Future<void> _prepareUserProjectWorkStream(
  FirebaseFirestore db,
  String userId,
  String projectId,
) =>
    _ensureUserProjectWorkIdMigratedOnce(db, userId, projectId).catchError(
      (e, st) => debugPrint('TG_Work: prepare user_project_work stream: $e\n$st'),
    );

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

  static void _patchIdeCountingFolderFsPath(
    Map<String, dynamic> map,
    Project oldProject,
    Project updated,
  ) {
    final prev = oldProject.ideCountingFolderFsPath.trim();
    final next = updated.ideCountingFolderFsPath.trim();
    if (prev == next) return;
    if (next.isEmpty) {
      map['ideCountingFolderFsPath'] = FieldValue.delete();
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
      ideCountingFolderFsPath: project.ideCountingFolderFsPath,
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
    _patchIdeCountingFolderFsPath(map, oldProject, updated);
    await _db.collection('projects').doc(project.id).update(map);

    final summary =
        summarizeProjectEdit(oldProject, updated) ?? 'Alteração: gravação registada';
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

  /// Para cada projeto, devolve a data mais antiga em que o estado passou para
  /// 'emExecucao'. O período Kanban só conta a partir dessa data — enquanto em
  /// 'Exequível' o projeto está em espera e não é contabilizado como trabalho.
  Stream<Map<String, DateTime>> watchProjectFirstExecutionDateMap() {
    return _db
        .collection('status_changes')
        .where('entityType', isEqualTo: 'project')
        .where('newStatusKey', isEqualTo: 'emExecucao')
        .snapshots()
        .map((snap) {
      final result = <String, DateTime>{};
      for (final d in snap.docs) {
        try {
          final sc = StatusChange.fromMap(d.data(), d.id);
          final existing = result[sc.entityId];
          if (existing == null || sc.changedAt.isBefore(existing)) {
            result[sc.entityId] = sc.changedAt;
          }
        } catch (_) {}
      }
      return result;
    });
  }

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

  // ─── Preferências de faturação (documento `user_settings/{userId}`) ─────

  DocumentReference<Map<String, dynamic>> _userSettingsRef(String userId) {
    return _db.collection('user_settings').doc(userId);
  }

  Stream<UserBillingSettings> watchUserBillingSettings(String userId) {
    return _userSettingsRef(userId).snapshots().map(
          (s) => UserBillingSettings.fromMap(s.data()),
        );
  }

  Future<void> setUserBillingSettings(
    String userId,
    UserBillingSettings settings,
  ) async {
    final data = <String, dynamic>{};
    if (settings.billingProjectId != null &&
        settings.billingProjectId!.trim().isNotEmpty) {
      data['billingProjectId'] = settings.billingProjectId!.trim();
    } else {
      data['billingProjectId'] = FieldValue.delete();
    }
    if (settings.hourlyRateEuros != null && settings.hourlyRateEuros! > 0) {
      data['hourlyRateEuros'] = settings.hourlyRateEuros;
    } else {
      data['hourlyRateEuros'] = FieldValue.delete();
    }
    await _userSettingsRef(userId).set(data, SetOptions(merge: true));
  }

  /// Chaves `tg:{id}` ou `ws:{workspace}` ocultas da Agenda IDE.
  Stream<Set<String>> watchIdeAgendaExcludedKeys(String userId) {
    if (userId.isEmpty) return Stream.value({});
    return _userSettingsRef(userId).snapshots().map((s) {
      final raw = s.data()?['ideAgendaExcludedAggregateKeys'];
      if (raw is! List) return <String>{};
      return raw
          .map((e) => e is String ? e.trim() : e.toString().trim())
          .where((k) => k.isNotEmpty)
          .toSet();
    });
  }

  Future<void> addIdeAgendaExcludedKeys(
    String userId,
    Iterable<String> aggregateKeys,
  ) async {
    if (userId.isEmpty) return;
    final keys = aggregateKeys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    if (keys.isEmpty) return;
    await _userSettingsRef(userId).set(
      {'ideAgendaExcludedAggregateKeys': FieldValue.arrayUnion(keys)},
      SetOptions(merge: true),
    );
  }

  /// Remove da Agenda IDE por nome de projeto TG Work ou workspace IDE.
  Future<void> removeFromIdeAgendaByDisplayName({
    required String userId,
    required String displayName,
    required List<Project> projects,
    required List<IdeScheduleCard> cards,
  }) async {
    if (userId.isEmpty) return;
    final name = displayName.trim();
    if (name.isEmpty) return;

    final keys = <String>{'ws:$name'};
    for (final p in projects) {
      if (p.name.trim().toLowerCase() == name.toLowerCase()) {
        keys.add('tg:${p.id}');
      }
    }

    for (final c in cards) {
      final matchTitle = c.title.trim().toLowerCase() == name.toLowerCase();
      final matchKey = c.aggregateKey.isNotEmpty && keys.contains(c.aggregateKey);
      final matchPid = c.tgProjectId.isNotEmpty && keys.contains('tg:${c.tgProjectId}');
      if (matchTitle || matchKey || matchPid) {
        if (c.aggregateKey.isNotEmpty) keys.add(c.aggregateKey);
        await deleteIdeScheduleCard(userId: userId, cardId: c.id);
      }
    }

    await addIdeAgendaExcludedKeys(userId, keys);
  }

  // ─── Tempo de trabalho (relógio por utilizador + total por projeto) ───────

  Stream<ActiveWorkClock?> watchActiveWorkClock(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _db.collection('user_work_clock').doc(userId).snapshots().map((s) {
      if (!s.exists) return null;
      final d = s.data()!;
      final pid = d['activeProjectId'] as String?;
      final ts = d['segmentStartedAt'] as Timestamp?;
      if (pid == null || pid.trim().isEmpty || ts == null) return null;
      return ActiveWorkClock(projectId: pid.trim(), segmentStartedAt: ts.toDate());
    });
  }

  /// Devolve um stream com o mapa {projectId -> totalSeconds} para todos os
  /// projectos com tempo registado pelo relógio do Kanban.
  Stream<Map<String, int>> watchAllProjectWorkedSeconds(String userId) {
    if (userId.isEmpty) return Stream.value({});
    return _db
        .collection('user_project_work')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final result = <String, int>{};
      for (final doc in snap.docs) {
        final pid = doc.data()['projectId'] as String?;
        if (pid == null || pid.trim().isEmpty) continue;
        final v = doc.data()['totalSeconds'];
        final secs = v is int ? v : (v is num ? v.toInt() : 0);
        result[pid.trim()] = secs;
      }
      return result;
    });
  }

  Stream<int> watchProjectWorkedSeconds(String userId, String projectId) {
    if (userId.isEmpty || projectId.isEmpty) return Stream.value(0);
    final modernRef =
        _db.collection('user_project_work').doc('${userId}__wk__$projectId');

    /// Após migração, ouve só o doc sem `:` no ID.
    return Stream.fromFuture(_prepareUserProjectWorkStream(_db, userId, projectId))
        .asyncExpand((_) => modernRef.snapshots().map((s) {
              final v = s.data()?['totalSeconds'];
              if (v is int) return v;
              if (v is num) return v.toInt();
              return 0;
            }));
  }

  void _transactionAddWorkedSeconds(
    Transaction tx,
    String userId,
    String projectId,
    int seconds,
  ) {
    if (seconds <= 0) return;
    final ref =
        _db.collection('user_project_work').doc('${userId}__wk__$projectId');
    tx.set(
      ref,
      {
        'userId': userId,
        'projectId': projectId,
        'totalSeconds': FieldValue.increment(seconds),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Inicia ou muda o projeto em que o tempo está a ser contado. Fecha o segmento anterior e acumula segundos.
  Future<void> startProjectWorkTimer(String userId, String projectId) async {
    if (userId.isEmpty || projectId.isEmpty) return;
    await _ensureUserProjectWorkIdMigratedOnce(_db, userId, projectId).catchError(
      (e, st) => debugPrint('TG_Work: migrate antes do relógio (start): $e\n$st'),
    );
    final clockRef = _db.collection('user_work_clock').doc(userId);
    try {
      final preSnap = await clockRef.get();
      final dynamic preData = preSnap.data();
      if (preData is Map<String, dynamic>) {
        final prevEarly = (preData['activeProjectId'] as String?)?.trim();
        if (prevEarly != null &&
            prevEarly.isNotEmpty &&
            prevEarly != projectId) {
          await _ensureUserProjectWorkIdMigratedOnce(_db, userId, prevEarly).catchError(
            (e, st) =>
                debugPrint('TG_Work: migrate projeto anterior antes do relógio: $e\n$st'),
          );
        }
      }
    } catch (_) {}
    await _db.runTransaction((tx) async {
      final snap = await tx.get(clockRef);
      final now = Timestamp.now();
      String? prevId;
      Timestamp? prevStart;
      if (snap.exists) {
        final d = snap.data()!;
        final a = d['activeProjectId'];
        final t = d['segmentStartedAt'];
        if (a is String && a.trim().isNotEmpty && t is Timestamp) {
          prevId = a.trim();
          prevStart = t;
        }
      }
      if (prevId == projectId && prevStart != null) return;

      if (prevId != null && prevStart != null) {
        final delta = now.toDate().difference(prevStart.toDate()).inSeconds;
        _transactionAddWorkedSeconds(tx, userId, prevId, delta);
      }
      tx.set(
        clockRef,
        {
          'activeProjectId': projectId,
          'segmentStartedAt': now,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Para o relógio e grava o segmento atual no total do projeto.
  Future<void> stopProjectWorkTimer(String userId) async {
    if (userId.isEmpty) return;
    final clockRef = _db.collection('user_work_clock').doc(userId);

    DocumentSnapshot<Map<String, dynamic>>? preloadSnap;
    try {
      preloadSnap = await clockRef.get();
    } catch (_) {}
    final d = preloadSnap?.data();
    final pidEarly = (d?['activeProjectId'] as String?)?.trim();
    if (pidEarly != null && pidEarly.isNotEmpty) {
      await _ensureUserProjectWorkIdMigratedOnce(_db, userId, pidEarly).catchError(
        (e, st) => debugPrint('TG_Work: migrate antes do relógio (stop): $e\n$st'),
      );
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(clockRef);
      if (!snap.exists) return;
      final d = snap.data()!;
      final pid = d['activeProjectId'] as String?;
      final st = d['segmentStartedAt'] as Timestamp?;
      if (pid == null || pid.trim().isEmpty || st == null) return;
      final now = Timestamp.now();
      final delta = now.toDate().difference(st.toDate()).inSeconds;
      _transactionAddWorkedSeconds(tx, userId, pid.trim(), delta);
      tx.set(
        clockRef,
        {
          'activeProjectId': FieldValue.delete(),
          'segmentStartedAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Ao sair do ecrã do projeto: só grava e limpa se o relógio activo for mesmo [projectId].
  Future<void> stopProjectWorkTimerIfMatchingProject(
    String userId,
    String projectId,
  ) async {
    if (userId.isEmpty || projectId.isEmpty) return;
    await _ensureUserProjectWorkIdMigratedOnce(_db, userId, projectId).catchError(
      (e, st) => debugPrint('TG_Work: migrate antes do relógio (leave): $e\n$st'),
    );
    final clockRef = _db.collection('user_work_clock').doc(userId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(clockRef);
      if (!snap.exists) return;
      final d = snap.data()!;
      final pid = d['activeProjectId'] as String?;
      final st = d['segmentStartedAt'] as Timestamp?;
      if (pid == null || pid.trim() != projectId || st == null) return;
      final now = Timestamp.now();
      final delta = now.toDate().difference(st.toDate()).inSeconds;
      _transactionAddWorkedSeconds(tx, userId, pid.trim(), delta);
      tx.set(
        clockRef,
        {
          'activeProjectId': FieldValue.delete(),
          'segmentStartedAt': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });
  }

  CollectionReference<Map<String, dynamic>> _ideScheduleCardsRef(String userId) =>
      _db.collection('user_ide_schedule').doc(userId).collection('cards');

  Stream<IdeSessionLogsQuerySnapshot> watchIdeSessionLogs(String userId,
      {int limit = 2500}) {
    if (userId.isEmpty) {
      return const Stream<IdeSessionLogsQuerySnapshot>.empty();
    }
    final lim = limit < 1 ? 1 : limit;
    return _db
        .collection('user_ide_session_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('closedAt', descending: true)
        .limit(lim)
        .snapshots()
        .map((snap) {
      final completed = <IdeSessionLog>[];
      final allParsed = <IdeSessionLog>[];
      for (final d in snap.docs) {
        final log = IdeSessionLog.fromFirestore(d.id, d.data());
        if (log != null) {
          allParsed.add(log);
          if (log.durationSeconds > 0) completed.add(log);
        }
      }
      final n = snap.docs.length;
      return IdeSessionLogsQuerySnapshot(
        allParsedSessions: allParsed,
        completedSessions: completed,
        queriedDocumentCount: n,
        hitQueryLimit: n >= lim,
      );
    });
  }

  /// Sessão introduzida na app (não pela extensão IDE).
  /// Conta para o Kanban / relatório da Agenda IDE como as sessões automáticas.
  Future<String> addManualIdeSession({
    required String userId,
    required String tgProjectId,
    required IdeSessionKind kind,
    required DateTime workDay,
    required int durationSeconds,
    String projectLabel = '',
    String notes = '',
  }) async {
    if (userId.isEmpty) throw ArgumentError('userId');
    if (tgProjectId.trim().isEmpty) throw ArgumentError('tgProjectId');
    if (durationSeconds <= 0) {
      throw ArgumentError('durationSeconds deve ser > 0');
    }

    final day = DateTime(workDay.year, workDay.month, workDay.day);
    final closedAt = day.add(const Duration(hours: 18));
    final openedAt = closedAt.subtract(Duration(seconds: durationSeconds));
    final label = projectLabel.trim().isEmpty
        ? 'Sessão manual'
        : projectLabel.trim();
    final note = notes.trim();

    final ref = _db.collection('user_ide_session_logs').doc();
    await ref.set({
      'userId': userId,
      'workspaceRoot': '',
      'workspaceName': note.isEmpty ? label : '$label · $note',
      'tgProjectId': tgProjectId.trim(),
      'editor': kind.storageKey,
      'openedAt': Timestamp.fromDate(openedAt),
      'closedAt': Timestamp.fromDate(closedAt),
      'durationSeconds': durationSeconds,
      'source': 'manual',
    });
    return ref.id;
  }

  /// Apaga só sessões manuais (`source == manual`) do próprio utilizador.
  Future<void> deleteManualIdeSession({
    required String userId,
    required String sessionId,
  }) async {
    if (userId.isEmpty || sessionId.isEmpty) return;
    final ref = _db.collection('user_ide_session_logs').doc(sessionId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    if ((data['userId'] as String?) != userId) {
      throw StateError('Sessão de outro utilizador');
    }
    if ((data['source'] as String?) != 'manual') {
      throw StateError('Só se podem apagar sessões manuais');
    }
    await ref.delete();
  }

  Stream<List<IdeScheduleCard>> watchIdeScheduleCards(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    return _ideScheduleCardsRef(userId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => IdeScheduleCard.fromFirestore(d.id, d.data()))
            .toList());
  }

  Future<List<Project>> _fetchAllProjectsOnce() async {
    final snap = await _db
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => Project.fromMap(d.data(), d.id)).toList();
  }

  /// Liga workspaces/cartões da agenda IDE à coleção `projects` (aba Projetos).
  Future<List<Project>> ensureIdeAgendaLinkedToProjectsTab({
    required String userId,
    required String userName,
    required List<IdeSessionLog> logs,
    required List<IdeScheduleCard> cards,
    List<IdeSessionLog>? allLogs,
    List<Project>? projects,
    Set<String> excludedAggregateKeys = const {},
  }) async {
    final parsedAll = allLogs ?? logs;
    final afterOrphans = await ensureProjectsForOrphanIdeReferences(
      userId: userId,
      userName: userName,
      allLogs: parsedAll,
      cards: cards,
      projects: projects,
      excludedAggregateKeys: excludedAggregateKeys,
    );
    final afterSessions = await ensureProjectsFromUnlinkedIdeSessions(
      userId: userId,
      userName: userName,
      logs: logs,
      projects: afterOrphans,
      excludedAggregateKeys: excludedAggregateKeys,
    );
    return ensureProjectsFromIdeScheduleCards(
      userId: userId,
      userName: userName,
      cards: cards,
      logs: logs,
      projects: afterSessions,
      excludedAggregateKeys: excludedAggregateKeys,
    );
  }

  /// Sessões/cartões com `tgProjectId` mas sem documento em `projects` (ex.: extensão resolveu ID que já não existe).
  Future<List<Project>> ensureProjectsForOrphanIdeReferences({
    required String userId,
    required String userName,
    required List<IdeSessionLog> allLogs,
    required List<IdeScheduleCard> cards,
    List<Project>? projects,
    Set<String> excludedAggregateKeys = const {},
  }) async {
    if (userId.isEmpty) return projects ?? [];

    var list = List<Project>.from(projects ?? await _fetchAllProjectsOnce());
    final orphans = orphanIdeProjectIdsWithLabels(
      allLogs: allLogs,
      cards: cards,
      projects: list,
    );
    if (orphans.isEmpty) return list;

    for (final entry in orphans.entries) {
      final pid = entry.key;
      if (isIdeAgendaAggregateKeyExcluded('tg:$pid', excludedAggregateKeys)) {
        continue;
      }

      final groupLogs =
          allLogs.where((l) => l.tgProjectId.trim() == pid).toList();
      final idePath = ideCountingPathFromLogs(groupLogs);
      final now = DateTime.now();
      final name = entry.value.trim().isNotEmpty ? entry.value.trim() : 'Projeto IDE';

      await _restoreProjectAtFirestoreId(
        projectId: pid,
        project: Project(
          id: pid,
          name: name,
          description:
              'Recuperado automaticamente a partir da agenda IDE (referência existente nas sessões).',
          status: ProjectStatus.exequivel,
          createdBy: userId,
          createdByName: userName,
          createdAt: now,
          ideCountingFolderFsPath: idePath,
        ),
        userId: userId,
        userName: userName,
      );

      list = [
        Project(
          id: pid,
          name: name,
          description:
              'Recuperado automaticamente a partir da agenda IDE (referência existente nas sessões).',
          status: ProjectStatus.exequivel,
          createdBy: userId,
          createdByName: userName,
          createdAt: now,
          ideCountingFolderFsPath: idePath,
        ),
        ...list.where((p) => p.id != pid),
      ];
      debugPrint('TG_Work: projeto restaurado na aba Projetos · id=$pid · $name');
    }

    return list;
  }

  Future<void> _restoreProjectAtFirestoreId({
    required String projectId,
    required Project project,
    required String userId,
    required String userName,
  }) async {
    if (projectId.isEmpty) return;
    final snap = await _db.collection('projects').doc(projectId).get();
    if (snap.exists) return;

    final now = DateTime.now();
    final actorName = normalizeStoredActorName(userName);
    await _db.collection('projects').doc(projectId).set(project.toMap());
    await _logAuditEntry(
      entityType: 'project',
      entityId: projectId,
      entityName: project.name,
      summaryLine: 'Criação do projeto (ligação agenda IDE)',
      userId: userId,
      userName: actorName,
      changedAt: now,
    );
  }

  /// Quando a IDE regista sessões sem `tgProjectId`, cria (ou liga) um documento em `projects`
  /// para aparecer na aba Projetos e nas sessões futuras com o ID correcto.
  Future<List<Project>> ensureProjectsFromUnlinkedIdeSessions({
    required String userId,
    required String userName,
    required List<IdeSessionLog> logs,
    List<Project>? projects,
    Set<String> excludedAggregateKeys = const {},
  }) async {
    if (userId.isEmpty) return projects ?? [];

    var list = List<Project>.from(projects ?? await _fetchAllProjectsOnce());
    final summaries = summarizeIdeSessionsByProject(logs, list)
        .where((s) =>
            s.isUnlinked &&
            !isIdeAgendaAggregateKeyExcluded(s.aggregateKey, excludedAggregateKeys))
        .toList();
    if (summaries.isEmpty) return list;

    for (final summary in summaries) {
      final groupLogs = ideLogsForWorkspaceAggregate(logs, summary);
      if (groupLogs.isEmpty) continue;

      var projectId = findExistingProjectIdForIdeGroup(
        summary: summary,
        groupLogs: groupLogs,
        projects: list,
      );

      if (projectId == null || projectId.isEmpty) {
        final now = DateTime.now();
        final name = suggestedProjectNameFromIdeGroup(summary, groupLogs);
        final idePath = ideCountingPathFromLogs(groupLogs);
        projectId = await addProject(
          Project(
            id: '',
            name: name,
            description:
                'Criado automaticamente a partir de sessões IDE (workspace).',
            status: ProjectStatus.exequivel,
            createdBy: userId,
            createdByName: userName,
            createdAt: now,
            ideCountingFolderFsPath: idePath,
          ),
          userId: userId,
          userName: userName,
        );
        list = [
          Project(
            id: projectId,
            name: name,
            description:
                'Criado automaticamente a partir de sessões IDE (workspace).',
            status: ProjectStatus.exequivel,
            createdBy: userId,
            createdByName: userName,
            createdAt: now,
            ideCountingFolderFsPath: idePath,
          ),
          ...list,
        ];
      }

      await _backfillIdeSessionTgProjectId(
        userId: userId,
        groupLogs: groupLogs,
        tgProjectId: projectId,
      );
      applyTgProjectIdToIdeLogsInPlace(
        logs: logs,
        groupLogs: groupLogs,
        tgProjectId: projectId,
      );
    }

    return list;
  }

  /// Cartões Kanban da agenda (`ws:…`) sem documento em `projects` → cria/liga na aba Projetos.
  Future<List<Project>> ensureProjectsFromIdeScheduleCards({
    required String userId,
    required String userName,
    required List<IdeScheduleCard> cards,
    required List<IdeSessionLog> logs,
    List<Project>? projects,
    Set<String> excludedAggregateKeys = const {},
  }) async {
    if (userId.isEmpty) return projects ?? [];

    var list = List<Project>.from(projects ?? await _fetchAllProjectsOnce());

    for (final card in cards) {
      if (isIdeScheduleCardExcluded(card, excludedAggregateKeys)) continue;

      final aggKey = ideScheduleCardAggregateKey(card);
      if (isIdeAgendaAggregateKeyExcluded(aggKey, excludedAggregateKeys)) {
        continue;
      }

      if (aggKey.startsWith('tg:')) {
        final pid = aggKey.substring(3).trim();
        if (pid.isNotEmpty && !list.any((p) => p.id == pid)) {
          final groupLogs =
              logs.where((l) => l.tgProjectId.trim() == pid).toList();
          final now = DateTime.now();
          final name = card.title.trim().isNotEmpty
              ? card.title.trim()
              : suggestedProjectNameFromIdeGroup(
                  IdeProjectSessionSummary(
                    aggregateKey: aggKey,
                    projectFirestoreId: pid,
                    workspaceName: '',
                    displayLabel: card.title,
                    sessionCount: groupLogs.length,
                    distinctLocalDays: 0,
                    totalDurationSeconds: card.ideTrackedSeconds,
                  ),
                  groupLogs,
                );
          await _restoreProjectAtFirestoreId(
            projectId: pid,
            project: Project(
              id: pid,
              name: name,
              description:
                  'Recuperado automaticamente a partir do cartão da agenda IDE.',
              status: ProjectStatus.exequivel,
              createdBy: userId,
              createdByName: userName,
              createdAt: now,
              ideCountingFolderFsPath: ideCountingPathFromLogs(groupLogs),
            ),
            userId: userId,
            userName: userName,
          );
          list = [
            Project(
              id: pid,
              name: name,
              description:
                  'Recuperado automaticamente a partir do cartão da agenda IDE.',
              status: ProjectStatus.exequivel,
              createdBy: userId,
              createdByName: userName,
              createdAt: now,
              ideCountingFolderFsPath: ideCountingPathFromLogs(groupLogs),
            ),
            ...list.where((p) => p.id != pid),
          ];
        }
        continue;
      }

      if (!aggKey.startsWith('ws:')) {
        continue;
      }

      final wsName = aggKey.length > 3 ? aggKey.substring(3) : card.title.trim();
      if (wsName.isEmpty) continue;

      final summary = IdeProjectSessionSummary(
        aggregateKey: aggKey,
        projectFirestoreId: '',
        workspaceName: wsName,
        displayLabel: card.title.trim().isNotEmpty ? card.title.trim() : wsName,
        sessionCount: 0,
        distinctLocalDays: 0,
        totalDurationSeconds: card.ideTrackedSeconds,
      );
      final groupLogs = ideLogsForWorkspaceAggregate(logs, summary);

      var projectId = findExistingProjectIdForIdeGroup(
        summary: summary,
        groupLogs: groupLogs,
        projects: list,
      );

      if (projectId == null || projectId.isEmpty) {
        final now = DateTime.now();
        final name = suggestedProjectNameFromIdeGroup(summary, groupLogs);
        final idePath = ideCountingPathFromLogs(groupLogs);
        projectId = await addProject(
          Project(
            id: '',
            name: name,
            description:
                'Criado automaticamente a partir da agenda IDE (Kanban).',
            status: ProjectStatus.exequivel,
            createdBy: userId,
            createdByName: userName,
            createdAt: now,
            ideCountingFolderFsPath: idePath,
          ),
          userId: userId,
          userName: userName,
        );
        list = [
          Project(
            id: projectId,
            name: name,
            description:
                'Criado automaticamente a partir da agenda IDE (Kanban).',
            status: ProjectStatus.exequivel,
            createdBy: userId,
            createdByName: userName,
            createdAt: now,
            ideCountingFolderFsPath: idePath,
          ),
          ...list,
        ];
      }

      if (groupLogs.isNotEmpty) {
        await _backfillIdeSessionTgProjectId(
          userId: userId,
          groupLogs: groupLogs,
          tgProjectId: projectId,
        );
        applyTgProjectIdToIdeLogsInPlace(
          logs: logs,
          groupLogs: groupLogs,
          tgProjectId: projectId,
        );
      }

      final linkedKey = 'tg:$projectId';
      if (card.tgProjectId != projectId || card.aggregateKey != linkedKey) {
        await _ideScheduleCardsRef(userId).doc(card.id).update({
          'tgProjectId': projectId,
          'aggregateKey': linkedKey,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return list;
  }

  Future<void> _backfillIdeSessionTgProjectId({
    required String userId,
    required List<IdeSessionLog> groupLogs,
    required String tgProjectId,
  }) async {
    if (userId.isEmpty || tgProjectId.isEmpty) return;
    var batch = _db.batch();
    var pending = 0;
    for (final log in groupLogs) {
      if (log.tgProjectId.trim().isNotEmpty) continue;
      if (log.id.isEmpty) continue;
      batch.update(
        _db.collection('user_ide_session_logs').doc(log.id),
        {'tgProjectId': tgProjectId},
      );
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = _db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }

  Future<String> createIdeScheduleCard({
    required String userId,
    required String title,
    String notes = '',
    IdeScheduleLane lane = IdeScheduleLane.backlog,
    String workDateIso = '',
    String tgProjectId = '',
    String aggregateKey = '',
    int ideTrackedSeconds = 0,
  }) async {
    if (userId.isEmpty) throw ArgumentError.notNull('userId');
    final col = _ideScheduleCardsRef(userId);
    final ref = col.doc();
    final order = DateTime.now().microsecondsSinceEpoch.toDouble();
    // Inferir aggregateKey se não fornecido
    final resolvedKey = aggregateKey.isNotEmpty
        ? aggregateKey
        : (tgProjectId.isNotEmpty ? 'tg:$tgProjectId' : '');
    final card = IdeScheduleCard(
      id: ref.id,
      title: title.trim().isEmpty ? '(sem título)' : title.trim(),
      notes: notes,
      lane: lane,
      workDateIso: workDateIso,
      tgProjectId: tgProjectId,
      aggregateKey: resolvedKey,
      ideTrackedSeconds: ideTrackedSeconds < 0 ? 0 : ideTrackedSeconds,
      sortOrder: order,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.set(card.toCreateMap(order));
    return ref.id;
  }

  /// Mantém um cartão Kanban por `aggregateKey` dos registos IDE.
  /// - `tg:{tgProjectId}`: sessões com projeto TG ligado
  /// - `ws:{workspaceName}`: sessões sem projeto (agrupadas por workspace)
  /// Cria automaticamente na primeira vez, actualiza tempo e título quando há sessões novas.
  Future<void> reconcileIdeKanbanFromIdeSessions({
    required String userId,
    required String userName,
    required List<IdeSessionLog> logs,
    required List<Project> projects,
    required List<IdeScheduleCard> cards,
    List<IdeSessionLog>? allLogs,
    Set<String> excludedAggregateKeys = const {},
  }) async {
    if (userId.isEmpty) return;

    final parsedAll = allLogs ?? logs;
    final projectsAfterOrphans = await ensureProjectsForOrphanIdeReferences(
      userId: userId,
      userName: userName,
      allLogs: parsedAll,
      cards: cards,
      projects: projects,
      excludedAggregateKeys: excludedAggregateKeys,
    );

    final projectsAfterSessions = await ensureProjectsFromUnlinkedIdeSessions(
      userId: userId,
      userName: userName,
      logs: logs,
      projects: projectsAfterOrphans,
      excludedAggregateKeys: excludedAggregateKeys,
    );

    final projectsAfterEnsure = await ensureProjectsFromIdeScheduleCards(
      userId: userId,
      userName: userName,
      cards: cards,
      logs: logs,
      projects: projectsAfterSessions,
      excludedAggregateKeys: excludedAggregateKeys,
    );

    final summaries = summarizeIdeSessionsByProject(logs, projectsAfterEnsure)
        .where((s) => !excludedAggregateKeys.contains(s.aggregateKey))
        .toList();
    final summaryKeys = summaries.map((s) => s.aggregateKey).toSet();

    // Apagar cartões de entradas excluídas da agenda
    for (final c in cards) {
      final k = c.aggregateKey.isNotEmpty
          ? c.aggregateKey
          : (c.tgProjectId.isNotEmpty ? 'tg:${c.tgProjectId}' : '');
      if (k.isNotEmpty && excludedAggregateKeys.contains(k)) {
        await deleteIdeScheduleCard(userId: userId, cardId: c.id);
      }
    }

    // Indexar cartões existentes por aggregateKey (preferência) ou por tgProjectId legacy
    final byKey = <String, List<IdeScheduleCard>>{};
    for (final c in cards) {
      final k = c.aggregateKey.isNotEmpty
          ? c.aggregateKey
          : (c.tgProjectId.isNotEmpty ? 'tg:${c.tgProjectId}' : '');
      if (k.isNotEmpty) {
        byKey.putIfAbsent(k, () => []).add(c);
      }
    }
    for (final list in byKey.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Cartões `ws:` órfãos depois de ligar sessões a um projecto TG (`tg:`).
    for (final c in cards) {
      final k = c.aggregateKey.isNotEmpty
          ? c.aggregateKey
          : (c.tgProjectId.isNotEmpty ? 'tg:${c.tgProjectId}' : '');
      if (k.startsWith('ws:') &&
          !summaryKeys.contains(k) &&
          !excludedAggregateKeys.contains(k)) {
        await deleteIdeScheduleCard(userId: userId, cardId: c.id);
      }
    }

    for (final s in summaries) {
      final aggKey = s.aggregateKey;
      final secs = s.totalDurationSeconds;
      final desiredTitle = s.displayLabel;
      final bucket = byKey[aggKey];

      if (bucket == null || bucket.isEmpty) {
        await createIdeScheduleCard(
          userId: userId,
          title: desiredTitle,
          notes: '',
          lane: IdeScheduleLane.backlog,
          workDateIso: '',
          tgProjectId: s.projectFirestoreId,
          aggregateKey: aggKey,
          ideTrackedSeconds: secs,
        );
        continue;
      }

      final primary = bucket.first;
      final linkedPid = s.projectFirestoreId;
      final needsUpdate = primary.ideTrackedSeconds != secs ||
          primary.title != desiredTitle ||
          primary.aggregateKey != aggKey ||
          (linkedPid.isNotEmpty && primary.tgProjectId != linkedPid);
      if (needsUpdate) {
        final patch = <String, dynamic>{
          'title': desiredTitle,
          'ideTrackedSeconds': secs,
          'aggregateKey': aggKey,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (linkedPid.isNotEmpty) {
          patch['tgProjectId'] = linkedPid;
        } else {
          patch['tgProjectId'] = FieldValue.delete();
        }
        await _ideScheduleCardsRef(userId).doc(primary.id).update(patch);
      }

      for (var i = 1; i < bucket.length; i++) {
        await deleteIdeScheduleCard(userId: userId, cardId: bucket[i].id);
      }
    }
  }

  Future<void> updateIdeScheduleCardLane({
    required String userId,
    required String cardId,
    required IdeScheduleLane lane,
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;
    await _ideScheduleCardsRef(userId).doc(cardId).update({
      'lane': lane.firebaseValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateIdeScheduleCard({
    required String userId,
    required String cardId,
    required String title,
    String notes = '',
    String workDateIso = '',
    String tgProjectId = '',
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;
    final ref = _ideScheduleCardsRef(userId).doc(cardId);
    final map = <String, dynamic>{
      'title': title.trim().isEmpty ? '(sem título)' : title.trim(),
      'notes': notes,
      'workDateIso': workDateIso,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (tgProjectId.isEmpty) {
      map['tgProjectId'] = FieldValue.delete();
    } else {
      map['tgProjectId'] = tgProjectId;
    }
    await ref.update(map);
  }

  Future<void> deleteIdeScheduleCard({
    required String userId,
    required String cardId,
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;
    await _ideScheduleCardsRef(userId).doc(cardId).delete();
  }

  // ─── Relatório por projeto (Agenda IDE → Firestore para outras apps) ───

  CollectionReference<Map<String, dynamic>> _ideProjectReportsRef(String userId) =>
      _db.collection('user_ide_project_reports').doc(userId).collection('by_project');

  Stream<List<IdeProjectReportSnapshot>> watchIdeProjectReports(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _ideProjectReportsRef(userId).snapshots().map((snap) {
      final list = <IdeProjectReportSnapshot>[];
      for (final d in snap.docs) {
        try {
          final item = IdeProjectReportSnapshot.fromFirestore(d.id, d.data());
          if (item != null) list.add(item);
        } catch (e, st) {
          debugPrint('TG_Work: ignorado report ${d.id}: $e\n$st');
        }
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  Stream<IdeProjectReportSnapshot?> watchIdeProjectReport(
    String userId,
    String projectId,
  ) {
    if (userId.isEmpty || projectId.isEmpty) return Stream.value(null);
    return _ideProjectReportsRef(userId).doc(projectId).snapshots().map((d) {
      if (!d.exists) return null;
      final data = d.data();
      if (data == null) return null;
      return IdeProjectReportSnapshot.fromFirestore(d.id, data);
    });
  }

  /// Grava totais do relatório por projeto. O ID do documento = [projectId].
  Future<void> upsertIdeProjectReport(IdeProjectReportSnapshot snapshot) async {
    if (snapshot.userId.isEmpty || snapshot.projectId.isEmpty) return;
    await _ideProjectReportsRef(snapshot.userId)
        .doc(snapshot.projectId)
        .set(snapshot.toMap(), SetOptions(merge: true));
  }

  /// Sincroniza todos os projetos TG Work (excepto excluídos da agenda).
  Future<void> syncIdeProjectReports({
    required String userId,
    required List<Project> projects,
    required List<IdeSessionLog> completedLogs,
    required Map<String, DateTime> firstExecDateByProjectId,
    Set<String> excludedAggregateKeys = const {},
  }) async {
    if (userId.isEmpty) return;

    final summaries = summarizeIdeSessionsByProject(completedLogs, projects);
    final summaryByProjectId = <String, IdeProjectSessionSummary>{
      for (final s in summaries)
        if (s.projectFirestoreId.isNotEmpty) s.projectFirestoreId: s,
    };

    for (final project in projects) {
      final aggKey = 'tg:${project.id}';
      if (excludedAggregateKeys.contains(aggKey)) continue;

      final snapshot = computeIdeProjectReportSnapshot(
        userId: userId,
        project: project,
        ideSummary: summaryByProjectId[project.id],
        execStartDate: firstExecDateByProjectId[project.id],
      );
      await upsertIdeProjectReport(snapshot);
    }
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
