import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
