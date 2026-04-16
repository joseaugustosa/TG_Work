import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/user_display.dart';
import '../utils/entity_change_summary.dart';
import '../models/project.dart';
import '../models/theme_item.dart';
import '../models/development.dart';
import '../models/status_change.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Projects ────────────────────────────────────────────────────────────

  Stream<List<Project>> getProjects() {
    return _db
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Project.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addProject(
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
      status: project.status,
      createdBy: project.createdBy,
      createdByName: project.createdByName,
      createdAt: project.createdAt,
      updatedBy: userId,
      updatedByName: actorName,
      updatedAt: now,
    );

    await _db.collection('projects').doc(project.id).update(updated.toMap());

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

  Future<void> addTheme(
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
      status: theme.status,
      projectId: theme.projectId,
      createdBy: theme.createdBy,
      createdByName: theme.createdByName,
      createdAt: theme.createdAt,
      updatedBy: userId,
      updatedByName: actorName,
      updatedAt: now,
    );

    await _db.collection('themes').doc(theme.id).update(updated.toMap());

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

  Future<void> addDevelopment(
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

    await _db.collection('developments').doc(dev.id).update(updated.toMap());

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
    await _db.collection('developments').doc(devId).delete();
  }

  Stream<Development?> watchDevelopment(String id) {
    return _db.collection('developments').doc(id).snapshots().map(
          (doc) => doc.exists ? Development.fromMap(doc.data()!, doc.id) : null,
        );
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
