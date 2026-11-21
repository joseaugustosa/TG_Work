/// Janela temporal para um segmento introduzido manualmente (fecho às 18h local).
({DateTime startedAt, DateTime endedAt}) manualWorkSegmentWindow(
  DateTime workDay,
  int durationSeconds,
) {
  if (durationSeconds <= 0) {
    throw ArgumentError('durationSeconds deve ser > 0');
  }
  final day = DateTime(workDay.year, workDay.month, workDay.day);
  final endedAt = day.add(const Duration(hours: 18));
  final startedAt = endedAt.subtract(Duration(seconds: durationSeconds));
  return (startedAt: startedAt, endedAt: endedAt);
}
