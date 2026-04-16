import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> addProject(Project project) async {
    await _db.collection('projects').add(project.toMap());
  }

  Future<void> updateProject(
    Project project, {
    required Project oldProject,
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
    final updated = Project(
      id: project.id,
      name: project.name,
      description: project.description,
      status: project.status,
      createdBy: project.createdBy,
      createdByName: project.createdByName,
      createdAt: project.createdAt,
      updatedBy: userId,
      updatedByName: userName,
      updatedAt: now,
    );

    await _db.collection('projects').doc(project.id).update(updated.toMap());

    if (oldProject.status != project.status) {
      await _logStatusChange(
        entityType: 'project',
        entityId: project.id,
        entityName: project.name,
        oldStatusKey: oldProject.status.key,
        oldStatusLabel: oldProject.status.label,
        newStatusKey: project.status.key,
        newStatusLabel: project.status.label,
        userId: userId,
        userName: userName,
        changedAt: now,
      );
    }
  }

  Future<void> deleteProject(String projectId) async {
    await _db.collection('projects').doc(projectId).delete();
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

  Future<void> addTheme(ThemeItem theme) async {
    await _db.collection('themes').add(theme.toMap());
  }

  Future<void> updateTheme(
    ThemeItem theme, {
    required ThemeItem oldTheme,
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
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
      updatedByName: userName,
      updatedAt: now,
    );

    await _db.collection('themes').doc(theme.id).update(updated.toMap());

    if (oldTheme.status != theme.status) {
      await _logStatusChange(
        entityType: 'theme',
        entityId: theme.id,
        entityName: theme.name,
        oldStatusKey: oldTheme.status.key,
        oldStatusLabel: oldTheme.status.label,
        newStatusKey: theme.status.key,
        newStatusLabel: theme.status.label,
        userId: userId,
        userName: userName,
        changedAt: now,
      );
    }
  }

  Future<void> deleteTheme(String themeId) async {
    await _db.collection('themes').doc(themeId).delete();
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

  Future<void> addDevelopment(Development dev) async {
    await _db.collection('developments').add(dev.toMap());
  }

  Future<void> updateDevelopment(
    Development dev, {
    required Development oldDev,
    required String userId,
    required String userName,
  }) async {
    final now = DateTime.now();
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
      updatedByName: userName,
      updatedAt: now,
    );

    await _db.collection('developments').doc(dev.id).update(updated.toMap());

    if (oldDev.status != dev.status) {
      await _logStatusChange(
        entityType: 'development',
        entityId: dev.id,
        entityName: dev.name,
        oldStatusKey: oldDev.status.key,
        oldStatusLabel: oldDev.status.label,
        newStatusKey: dev.status.key,
        newStatusLabel: dev.status.label,
        userId: userId,
        userName: userName,
        changedAt: now,
      );
    }
  }

  Future<void> deleteDevelopment(String devId) async {
    await _db.collection('developments').doc(devId).delete();
  }

  // ─── Status History ───────────────────────────────────────────────────────

  Stream<List<StatusChange>> getStatusHistory(String entityId) {
    return _db
        .collection('status_changes')
        .where('entityId', isEqualTo: entityId)
        .orderBy('changedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StatusChange.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<void> _logStatusChange({
    required String entityType,
    required String entityId,
    required String entityName,
    required String oldStatusKey,
    required String oldStatusLabel,
    required String newStatusKey,
    required String newStatusLabel,
    required String userId,
    required String userName,
    required DateTime changedAt,
  }) async {
    final change = StatusChange(
      id: '',
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      oldStatusKey: oldStatusKey,
      oldStatusLabel: oldStatusLabel,
      newStatusKey: newStatusKey,
      newStatusLabel: newStatusLabel,
      changedBy: userId,
      changedByName: userName,
      changedAt: changedAt,
    );
    await _db.collection('status_changes').add(change.toMap());
  }
}
