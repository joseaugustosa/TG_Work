import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Garante perfil `app_users` e impede entrada se bloqueado/apagado.
class AccessGate extends StatefulWidget {
  const AccessGate({super.key, required this.child});

  final Widget child;

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  late final Future<AppUser?> _ensureFuture;

  @override
  void initState() {
    super.initState();
    _ensureFuture = _ensure();
  }

  Future<AppUser?> _ensure() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return _fs.ensureAppUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    );
  }

  Future<void> _signOut() => _auth.signOut();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FutureBuilder<AppUser?>(
      future: _ensureFuture,
      builder: (context, ensureSnap) {
        if (ensureSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (ensureSnap.hasError) {
          return _BlockedScaffold(
            title: 'Não foi possível validar o acesso',
            message: '${ensureSnap.error}',
            onSignOut: _signOut,
          );
        }
        return StreamBuilder<AppUser?>(
          stream: _fs.watchAppUser(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = snap.data ?? ensureSnap.data;
            if (profile != null && !profile.isActive) {
              final reason = profile.deleted
                  ? 'A tua conta foi removida por um administrador.'
                  : 'A tua conta está bloqueada. Contacta um administrador.';
              return _BlockedScaffold(
                title: 'Acesso negado',
                message: reason,
                onSignOut: _signOut,
              );
            }
            return widget.child;
          },
        );
      },
    );
  }
}

class _BlockedScaffold extends StatelessWidget {
  const _BlockedScaffold({
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  final String title;
  final String message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => onSignOut(),
                  child: const Text('Terminar sessão'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
