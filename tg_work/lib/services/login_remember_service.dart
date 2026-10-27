import 'package:shared_preferences/shared_preferences.dart';

/// Guarda email e palavra-passe no dispositivo (opção «Memorizar»).
class LoginRememberService {
  static const _kRemember = 'login_remember';
  static const _kEmail = 'login_email';
  static const _kPassword = 'login_password';

  Future<({bool remember, String email, String password})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_kRemember) ?? false;
    if (!remember) {
      return (remember: false, email: '', password: '');
    }
    return (
      remember: true,
      email: prefs.getString(_kEmail) ?? '',
      password: prefs.getString(_kPassword) ?? '',
    );
  }

  Future<void> save({
    required bool remember,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!remember) {
      await clear();
      return;
    }
    await prefs.setBool(_kRemember, true);
    await prefs.setString(_kEmail, email.trim());
    await prefs.setString(_kPassword, password);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRemember);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPassword);
  }
}
