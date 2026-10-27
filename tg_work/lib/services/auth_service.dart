import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _secondaryAppName = 'tg_work_admin_create';

  Stream<User?> get userStream => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  /// Após criar conta: associa o nome ao utilizador e recarrega o perfil para a app o ver de imediato.
  Future<void> applyDisplayNameAfterRegistration(User user, String displayName) async {
    final n = displayName.trim();
    if (n.isEmpty) return;
    await user.updateDisplayName(n);
    await user.reload();
  }

  /// Alterar o nome no perfil (sessão atual). As novas auditorias passam a usar este nome.
  Future<void> updateProfileDisplayName(String displayName) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Sem sessão');
    final n = displayName.trim();
    if (n.isEmpty) throw ArgumentError('O nome não pode estar vazio');
    await u.updateDisplayName(n);
    await u.reload();
  }

  /// Cria conta Auth sem trocar a sessão do admin (FirebaseApp secundária).
  Future<User> createUserWithoutSwitchingSession({
    required String email,
    required String password,
    required String displayName,
  }) async {
    FirebaseApp? secondary;
    try {
      try {
        secondary = Firebase.app(_secondaryAppName);
      } catch (_) {
        secondary = await Firebase.initializeApp(
          name: _secondaryAppName,
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw StateError('Conta criada sem utilizador Auth');
      }
      final name = displayName.trim();
      if (name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      await secondaryAuth.signOut();
      return user;
    } finally {
      if (secondary != null) {
        try {
          await secondary.delete();
        } catch (_) {}
      }
    }
  }
}
