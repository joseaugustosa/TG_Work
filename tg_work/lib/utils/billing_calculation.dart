import 'package:intl/intl.dart';
import '../models/project.dart';

bool projectIsClosedForBilling(Project p) {
  return p.status == ProjectStatus.concluido || p.status == ProjectStatus.naoExequivel;
}

/// Tempo usado para faturação: desde a criação até agora (em curso) ou até a última atualização quando fechado.
Duration billingDurationForProject(Project p) {
  if (projectIsClosedForBilling(p)) {
    final end = (p.updatedAt != null && p.updatedAt!.isAfter(p.createdAt))
        ? p.updatedAt!
        : p.createdAt;
    var span = end.difference(p.createdAt);
    if (span.isNegative) span = Duration.zero;
    return span;
  }
  final span = DateTime.now().difference(p.createdAt);
  return span.isNegative ? Duration.zero : span;
}

double estimatedExpenseEuros(Duration d, double hourlyRateEuros) {
  if (hourlyRateEuros <= 0) return 0;
  final hours = d.inMicroseconds / Duration.microsecondsPerHour;
  return hours * hourlyRateEuros;
}

String formatEurosPt(double amount) {
  return NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2)
      .format(amount);
}

String describeBillingDurationShort(Duration d) {
  final totalMinutes = d.inMinutes;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0 && m > 0) return '$h h $m min';
  if (h > 0) return '$h h';
  if (m > 0) return '$m min';
  return '0 min';
}
