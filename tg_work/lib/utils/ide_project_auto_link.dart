import 'package:path/path.dart' as p;

import '../models/ide_schedule_card.dart';
import '../models/ide_session_log.dart';
import '../models/project.dart';
import 'ide_project_session_summary.dart';

/// Normaliza caminhos Windows/Unix para comparação (minúsculas, barras `/`).
String normalizeIdeFilesystemPath(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = s.replaceAll('\\', '/');
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s.toLowerCase();
}

/// Igual à heurística da extensão VS Code (`collapseNameRough`).
String collapseProjectNameRough(String raw) {
  return raw
      .trim()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('-', '')
      .toLowerCase();
}

/// Sessões IDE do mesmo agrupamento `ws:{workspaceName}`.
List<IdeSessionLog> ideLogsForWorkspaceAggregate(
  List<IdeSessionLog> logs,
  IdeProjectSessionSummary summary,
) {
  final key = summary.aggregateKey;
  return logs.where((l) => ideSessionAggregateKey(l) == key).toList();
}

/// Melhor caminho de contagem IDE a partir das sessões (raiz do workspace).
String ideCountingPathFromLogs(List<IdeSessionLog> groupLogs) {
  for (final log in groupLogs) {
    final root = log.workspaceRoot.trim();
    if (root.isNotEmpty) return root;
  }
  return '';
}

/// Nome sugerido para um novo projeto TG Work a partir do workspace IDE.
String suggestedProjectNameFromIdeGroup(
  IdeProjectSessionSummary summary,
  List<IdeSessionLog> groupLogs,
) {
  final ws = summary.workspaceName.trim();
  if (ws.isNotEmpty) return ws;
  final path = ideCountingPathFromLogs(groupLogs);
  if (path.isNotEmpty) return p.basename(p.normalize(path));
  return 'Projeto IDE';
}

/// Procura projecto existente que já corresponda a este workspace IDE.
String? findExistingProjectIdForIdeGroup({
  required IdeProjectSessionSummary summary,
  required List<IdeSessionLog> groupLogs,
  required List<Project> projects,
}) {
  final countingPath = normalizeIdeFilesystemPath(ideCountingPathFromLogs(groupLogs));
  if (countingPath.isNotEmpty) {
    for (final project in projects) {
      final stored = normalizeIdeFilesystemPath(project.ideCountingFolderFsPath);
      if (stored.isNotEmpty && stored == countingPath) {
        return project.id;
      }
    }
  }

  final wsSlug = collapseProjectNameRough(summary.workspaceName);
  if (wsSlug.isEmpty) return null;

  String? hit;
  for (final project in projects) {
    if (collapseProjectNameRough(project.name) != wsSlug) continue;
    if (hit != null) return null;
    hit = project.id;
  }
  return hit;
}

/// IDs referenciados nas sessões/cartões IDE que ainda não existem em `projects`.
Map<String, String> orphanIdeProjectIdsWithLabels({
  required List<IdeSessionLog> allLogs,
  required List<IdeScheduleCard> cards,
  required List<Project> projects,
}) {
  final existing = {for (final p in projects) p.id};
  final labels = <String, String>{};

  void note(String id, String label) {
    if (id.isEmpty || existing.contains(id)) return;
    final l = label.trim();
    labels.putIfAbsent(
      id,
      () => l.isNotEmpty ? l : 'Projeto IDE',
    );
    if (l.isNotEmpty && labels[id] == 'Projeto IDE') {
      labels[id] = l;
    }
  }

  for (final log in allLogs) {
    final pid = log.tgProjectId.trim();
    if (pid.isEmpty) continue;
    final ws = log.workspaceName.trim();
    note(pid, ws.isNotEmpty ? ws : pid);
  }

  for (final card in cards) {
    final pid = card.tgProjectId.trim();
    if (pid.isNotEmpty) {
      note(pid, card.title.trim());
    }
    final key = ideScheduleCardAggregateKey(card);
    if (key.startsWith('tg:')) {
      final id = key.substring(3).trim();
      note(id, card.title.trim());
    }
  }

  return labels;
}

/// Reflecte no array em memória o `tgProjectId` gravado no Firestore (mesmo ciclo de reconcile).
void applyTgProjectIdToIdeLogsInPlace({
  required List<IdeSessionLog> logs,
  required Iterable<IdeSessionLog> groupLogs,
  required String tgProjectId,
}) {
  if (tgProjectId.isEmpty) return;
  final ids = {for (final l in groupLogs) l.id};
  for (var i = 0; i < logs.length; i++) {
    final log = logs[i];
    if (!ids.contains(log.id) || log.tgProjectId.trim().isNotEmpty) continue;
    logs[i] = log.copyWith(tgProjectId: tgProjectId);
  }
}
