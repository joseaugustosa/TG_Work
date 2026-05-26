/// Preferências de faturação por tempo (documento `user_settings/{uid}` no Firestore).
class UserBillingSettings {
  final String? billingProjectId;
  /// Preço por hora em euros (ex.: 35.5).
  final double? hourlyRateEuros;

  const UserBillingSettings({
    this.billingProjectId,
    this.hourlyRateEuros,
  });

  factory UserBillingSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserBillingSettings();
    final id = map['billingProjectId'];
    final rate = map['hourlyRateEuros'];
    return UserBillingSettings(
      billingProjectId: id is String && id.trim().isNotEmpty ? id.trim() : null,
      hourlyRateEuros: rate is num ? rate.toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (billingProjectId != null && billingProjectId!.trim().isNotEmpty)
        'billingProjectId': billingProjectId!.trim(),
      if (hourlyRateEuros != null) 'hourlyRateEuros': hourlyRateEuros,
    };
  }
}
