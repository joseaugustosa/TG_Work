/// Formata segundos para leitura humana (tempo de trabalho registado).
String formatWorkDurationSeconds(int totalSeconds) {
  var t = totalSeconds;
  if (t < 0) t = 0;
  final h = t ~/ 3600;
  final m = (t % 3600) ~/ 60;
  final s = t % 60;
  if (h > 0) {
    return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }
  if (m > 0) {
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
  return '${s}s';
}
