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

/// Resumo de tempo para o card de projeto no Kanban:
/// - Exequível: só mostra a data de inserção (sem tempo)
/// - Em Execução: mostra desde quando está em execução (usa [execSinceDate] se disponível)
/// - Concluído/Não Exequível: duração total desde [execSinceDate] (ou [createdAt]) até [updatedAt]
String kanbanTimeSummaryPt({
  required DateTime createdAt,
  DateTime? updatedAt,
  required bool isDone,
  bool isExequivel = false,
  DateTime? execSinceDate,
}) {
  final fmtShort = DateFormat('dd/MM/yy');
  final fmtFull = DateFormat('dd/MM/yyyy HH:mm');

  if (isExequivel) {
    return 'Inserido em ${fmtShort.format(createdAt)}';
  }

  if (isDone) {
    final start = execSinceDate ?? createdAt;
    final end = (updatedAt != null && updatedAt.isAfter(start)) ? updatedAt : start;
    final span = end.difference(start);
    return 'Concluído em ${_describeDurationPt(span)} · até ${fmtFull.format(end)}';
  }

  // Em Execução (ou outro estado activo)
  final start = execSinceDate ?? createdAt;
  final span = DateTime.now().difference(start);
  final label = execSinceDate != null ? 'Em execução' : 'Em curso';
  return '$label há ${_describeDurationPt(span)} · desde ${fmtShort.format(start)}';
}
