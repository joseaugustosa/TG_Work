/// Horas de trabalho Kanban contabilizadas por dia de calendário no relatório IDE.
const int kanbanWorkHoursPerCalendarDay = 8;

const int _kanbanWorkSecondsPerDay = kanbanWorkHoursPerCalendarDay * 3600;

/// Dias de calendário inteiros entre [start] e [end] (inclusive em ambas as datas).
int kanbanIdeReportDayCount(DateTime start, DateTime end) {
  if (!end.isAfter(start)) return 0;
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return e.difference(s).inDays + 1;
}

/// Período Kanban pré-IDE (igual ao pill do relatório). Sem período → ambos null.
({DateTime? start, DateTime? end}) kanbanIdeReportPeriod({
  required DateTime projectCreatedAt,
  DateTime? execStartDate,
  DateTime? firstIdeSessionAt,
  required bool isExequivel,
  DateTime? now,
}) {
  if (isExequivel) return (start: null, end: null);
  final start = execStartDate ?? projectCreatedAt;
  if (firstIdeSessionAt == null) {
    final end = now ?? DateTime.now();
    if (!start.isBefore(end)) return (start: null, end: null);
    return (start: start, end: end);
  }
  if (start.isBefore(firstIdeSessionAt)) {
    return (start: start, end: firstIdeSessionAt);
  }
  return (start: null, end: null);
}

/// Segundos Kanban para totais: dias de calendário × 8 h.
int kanbanWorkSecondsFromIdePeriod(DateTime start, DateTime end) {
  final days = kanbanIdeReportDayCount(start, end);
  if (days <= 0) return 0;
  return days * _kanbanWorkSecondsPerDay;
}

int kanbanWorkSecondsForIdeReport({
  required DateTime projectCreatedAt,
  DateTime? execStartDate,
  DateTime? firstIdeSessionAt,
  required bool isExequivel,
  DateTime? now,
}) {
  final period = kanbanIdeReportPeriod(
    projectCreatedAt: projectCreatedAt,
    execStartDate: execStartDate,
    firstIdeSessionAt: firstIdeSessionAt,
    isExequivel: isExequivel,
    now: now,
  );
  final start = period.start;
  final end = period.end;
  if (start == null || end == null) return 0;
  return kanbanWorkSecondsFromIdePeriod(start, end);
}

/// Texto de duração do pill Kanban (mesmo número de dias que entra no × 8 h).
String kanbanIdeReportSpanLabelPt(DateTime from, DateTime to) {
  final days = kanbanIdeReportDayCount(from, to);
  if (days <= 0) return '< 1 dia';
  if (days < 31) return '$days ${days == 1 ? 'dia' : 'dias'}';
  final months = days ~/ 30;
  final rest = days % 30;
  if (rest == 0) return '$months ${months == 1 ? 'mês' : 'meses'}';
  return '$months ${months == 1 ? 'mês' : 'meses'} $rest dias';
}
