import '../models/ide_session_log.dart';

/// Chave de agrupamento de um registo de sessão:
///   - `tg:{tgProjectId}` quando há projeto TG ligado
///   - `ws:{workspaceName}` quando não há projeto (agrupado por workspace)
String sessionAggregateKey(IdeSessionLog log) {
  final pid = log.tgProjectId.trim();
  if (pid.isNotEmpty) return 'tg:$pid';
  final ws = log.workspaceName.trim();
  return 'ws:$ws';
}

/// Segundos por chave composta (`tg:{pid}` ou `ws:{workspaceName}`).
typedef ProjectSeconds = Map<String, int>;

ProjectSeconds _mergeMaps(ProjectSeconds a, ProjectSeconds b) {
  final out = Map<String, int>.from(a);
  for (final e in b.entries) {
    out[e.key] = (out[e.key] ?? 0) + e.value;
  }
  return out;
}

int sumProjectSeconds(ProjectSeconds m) => m.values.fold<int>(0, (s, v) => s + v);

/// Agrupa por dia de calendário **local** usando [IdeSessionLog.closedAt].
Map<DateTime, ProjectSeconds> rollupIdeSessionsByClosedDay(List<IdeSessionLog> logs) {
  final map = <DateTime, ProjectSeconds>{};
  for (final log in logs) {
    final d = IdeSessionLog.localCalendarDay(log.closedAt);
    final key = sessionAggregateKey(log);
    map.putIfAbsent(d, () => {});
    map[d]![key] = (map[d]![key] ?? 0) + log.durationSeconds;
  }
  return map;
}

Map<DateTime, ProjectSeconds> rollupByMonthFromDays(Map<DateTime, ProjectSeconds> byDay) {
  final map = <DateTime, ProjectSeconds>{};
  for (final e in byDay.entries) {
    final mk = DateTime(e.key.year, e.key.month);
    map[mk] = _mergeMaps(map[mk] ?? {}, e.value);
  }
  return map;
}

Map<int, ProjectSeconds> rollupByYearFromDays(Map<DateTime, ProjectSeconds> byDay) {
  final map = <int, ProjectSeconds>{};
  for (final e in byDay.entries) {
    map[e.key.year] = _mergeMaps(map[e.key.year] ?? {}, e.value);
  }
  return map;
}
