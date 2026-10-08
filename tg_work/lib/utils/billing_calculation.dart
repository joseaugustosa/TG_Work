import 'package:intl/intl.dart';

/// Despesa = horas trabalhadas × valor por hora (€).
double estimatedExpenseEuros(Duration d, double hourlyRateEuros) {
  if (hourlyRateEuros <= 0) return 0;
  if (d.isNegative || d == Duration.zero) return 0;
  final hours = d.inMicroseconds / Duration.microsecondsPerHour;
  return hours * hourlyRateEuros;
}

/// Variante directa a partir de segundos trabalhados.
double estimatedExpenseFromSeconds(int seconds, double hourlyRateEuros) {
  if (seconds <= 0) return 0;
  return estimatedExpenseEuros(Duration(seconds: seconds), hourlyRateEuros);
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
