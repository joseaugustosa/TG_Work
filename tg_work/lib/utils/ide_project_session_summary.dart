import '../models/ide_schedule_card.dart';
import '../models/ide_session_log.dart';
import '../models/project.dart';

/// Totais de sessões IDE agrupadas por projeto TG Work ou, quando sem ID, por nome de workspace.
///
/// Dias = dias de calendário locais distintos com pelo menos uma abertura (`openedAt`).
class IdeProjectSessionSummary {
  /// Chave de agrupamento estável:
  ///   - sessões com tgProjectId: `tg:{tgProjectId}`
  ///   - sessões sem tgProjectId: `ws:{workspaceName}` (ou `ws:` se workspaceName vazio)
  final String aggregateKey;

  final String projectFirestoreId;

  /// Nome do workspace quando não há tgProjectId ligado (pode ser vazio).
  final String workspaceName;

  /// Rótulo mostrado (nome do projeto TG, nome do workspace, ou «Sem workspace»).
  final String displayLabel;

  final int sessionCount;
  final int distinctLocalDays;
  final int totalDurationSeconds;

  /// Data da sessão IDE mais antiga para este projeto/workspace.
  /// Representa o início do período coberto pelo IDE tracking.
  final DateTime? earliestIdeSessionDate;

  const IdeProjectSessionSummary({
    required this.aggregateKey,
    required this.projectFirestoreId,
    required this.workspaceName,
    required this.displayLabel,
    required this.sessionCount,
    required this.distinctLocalDays,
    required this.totalDurationSeconds,
    this.earliestIdeSessionDate,
  });

  /// Verdade quando não há nenhum projeto TG Work ligado — agrupado por workspace.
  bool get isUnlinked => projectFirestoreId.isEmpty;
}

/// Chave estável de agrupamento para uma sessão IDE.
String ideSessionAggregateKey(IdeSessionLog log) {
  final pid = log.tgProjectId.trim();
  if (pid.isNotEmpty) return 'tg:$pid';
  return 'ws:${log.workspaceName.trim()}';
}

/// Chave estável de agrupamento para um cartão Kanban da agenda IDE.
String ideScheduleCardAggregateKey(IdeScheduleCard card) {
  if (card.aggregateKey.trim().isNotEmpty) return card.aggregateKey.trim();
  if (card.tgProjectId.trim().isNotEmpty) return 'tg:${card.tgProjectId.trim()}';
  return 'ws:${card.title.trim()}';
}

bool isIdeAgendaAggregateKeyExcluded(String key, Set<String> excludedKeys) {
  final k = key.trim();
  return k.isNotEmpty && excludedKeys.contains(k);
}

bool isIdeSessionLogExcluded(IdeSessionLog log, Set<String> excludedKeys) =>
    isIdeAgendaAggregateKeyExcluded(ideSessionAggregateKey(log), excludedKeys);

bool isIdeScheduleCardExcluded(IdeScheduleCard card, Set<String> excludedKeys) =>
    isIdeAgendaAggregateKeyExcluded(ideScheduleCardAggregateKey(card), excludedKeys);

bool isProjectExcludedFromIdeAgenda(Project project, Set<String> excludedKeys) =>
    isIdeAgendaAggregateKeyExcluded('tg:${project.id}', excludedKeys);

List<IdeProjectSessionSummary> summarizeIdeSessionsByProject(
  List<IdeSessionLog> logs,
  List<Project> projects,
) {
  final idToName = {for (final p in projects) p.id: p.name};

  // Agrupar por chave composta: tg:{pid} ou ws:{workspaceName}
  final byKey = <String, List<IdeSessionLog>>{};
  for (final log in logs) {
    final pid = log.tgProjectId.trim();
    final key = pid.isNotEmpty
        ? 'tg:$pid'
        : 'ws:${log.workspaceName.trim()}';
    byKey.putIfAbsent(key, () => []).add(log);
  }

  final out = byKey.entries.map((e) {
    final key = e.key;
    final list = e.value;

    final daySet = list.map((l) => IdeSessionLog.localCalendarDay(l.openedAt)).toSet();
    final totalSecs = list.fold<int>(0, (sum, l) => sum + l.durationSeconds);
    final earliest = list.map((l) => l.openedAt).reduce((a, b) => a.isBefore(b) ? a : b);

    String pid = '';
    String wsName = '';
    String label;

    if (key.startsWith('tg:')) {
      pid = key.substring(3);
      label = idToName[pid] ?? 'Projeto desconhecido (ID: $pid)';
    } else {
      wsName = key.length > 3 ? key.substring(3) : '';
      label = wsName.isNotEmpty ? wsName : 'Sem workspace';
    }

    return IdeProjectSessionSummary(
      aggregateKey: key,
      projectFirestoreId: pid,
      workspaceName: wsName,
      displayLabel: label,
      sessionCount: list.length,
      distinctLocalDays: daySet.length,
      totalDurationSeconds: totalSecs,
      earliestIdeSessionDate: earliest,
    );
  }).toList();

  out.sort((a, b) {
    // Projectos TG Work primeiro, depois workspaces não ligados
    if (a.isUnlinked != b.isUnlinked) return a.isUnlinked ? 1 : -1;
    final c = b.totalDurationSeconds.compareTo(a.totalDurationSeconds);
    return c != 0 ? c : a.displayLabel.compareTo(b.displayLabel);
  });

  return out;
}
