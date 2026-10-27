import 'package:intl/intl.dart';

String _describeDurationPt(Duration d) {
  var x = d;
  if (x.isNegative) x = Duration.zero;
  final days = x.inDays;
  final hours = x.inHours % 24;
  final minutes = x.inMinutes % 60;
  if (days >= 1) {
    if (hours >= 1) {
      return '$days ${days == 1 ? 'dia' : 'dias'} e $hours h';
    }
    return '$days ${days == 1 ? 'dia' : 'dias'}';
  }
  if (x.inHours >= 1) {
    if (minutes >= 1) return '${x.inHours} h $minutes min';
    return '${x.inHours} h';
  }
  if (x.inMinutes >= 1) return '${x.inMinutes} min';
  return 'menos de 1 min';
}

Duration _activeSpan({
  required DateTime start,
  required DateTime end,
  required int totalPausedMs,
}) {
  var span = end.difference(start);
  if (totalPausedMs > 0) {
    span -= Duration(milliseconds: totalPausedMs);
  }
  if (span.isNegative) return Duration.zero;
  return span;
}

/// Resumo de tempo para o card de projeto no Kanban:
/// - Exequível: só mostra a data de inserção (sem tempo)
/// - Em Execução: tempo ativo (exclui pausas acumuladas)
/// - Pausa: contagem parada
/// - Concluído/Não Exequível: duração ativa até ao fecho
String kanbanTimeSummaryPt({
  required DateTime createdAt,
  DateTime? updatedAt,
  required bool isDone,
  bool isExequivel = false,
  bool isPausa = false,
  DateTime? execSinceDate,
  DateTime? pausedAt,
  int totalPausedMs = 0,
}) {
  final fmtShort = DateFormat('dd/MM/yy');
  final fmtFull = DateFormat('dd/MM/yyyy HH:mm');

  if (isExequivel) {
    return 'Inserido em ${fmtShort.format(createdAt)}';
  }

  if (isPausa) {
    final since = pausedAt ?? updatedAt ?? createdAt;
    return 'Em pausa · desde ${fmtShort.format(since)} (contagem parada)';
  }

  if (isDone) {
    final start = execSinceDate ?? createdAt;
    final end =
        (updatedAt != null && updatedAt.isAfter(start)) ? updatedAt : start;
    final span = _activeSpan(
      start: start,
      end: end,
      totalPausedMs: totalPausedMs,
    );
    return 'Concluído em ${_describeDurationPt(span)} · até ${fmtFull.format(end)}';
  }

  // Em Execução (ou outro estado activo)
  final start = execSinceDate ?? createdAt;
  final span = _activeSpan(
    start: start,
    end: DateTime.now(),
    totalPausedMs: totalPausedMs,
  );
  final label = execSinceDate != null ? 'Em execução' : 'Em curso';
  return '$label há ${_describeDurationPt(span)} · desde ${fmtShort.format(start)}';
}
