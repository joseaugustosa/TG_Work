import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'firestore_service.dart';

/// Atualiza dados de utilizador (incl. Auth email/password).
///
/// - Conta própria: APIs Auth do cliente.
/// - Outros: Cloud Function (se existir) ou, no Windows, Admin via
///   `gcloud` ADC / script Node (como os outros scripts do repo).
class AdminUserService {
  AdminUserService({FirestoreService? firestore})
      : _fs = firestore ?? FirestoreService();

  final FirestoreService _fs;
  static const _projectId = 'tg-work-2026';

  Future<String?> updateUser({
    required AppUser user,
    required String displayName,
    required String email,
    String? newPassword,
    AppUserRole? role,
  }) async {
    final name = displayName.trim();
    final mail = email.trim().toLowerCase();
    final pass = newPassword?.trim() ?? '';
    if (mail.isEmpty) {
      throw ArgumentError('O email é obrigatório.');
    }
    if (pass.isNotEmpty && pass.length < 6) {
      throw ArgumentError('A palavra-passe precisa de pelo menos 6 caracteres.');
    }

    final selfUid = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = selfUid != null && selfUid == user.id;

    if (isSelf) {
      return _updateSelf(
        user: user,
        name: name,
        mail: mail,
        pass: pass,
        role: role,
      );
    }

    Future<void> propagateName() async {
      if (name.isEmpty) return;
      await _fs.updateAppUserDisplayNameAndPropagate(
        uid: user.id,
        displayName: name,
      );
    }

    // 1) Cloud Function (plano Blaze)
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('adminUpdateUser');
      await callable.call(<String, dynamic>{
        'uid': user.id,
        'displayName': name,
        'email': mail,
        if (pass.isNotEmpty) 'password': pass,
        if (role != null) 'role': role.key,
      });
      await propagateName();
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('TG_Work: adminUpdateUser CF: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('TG_Work: adminUpdateUser CF: $e');
    }

    // 2) Windows: Identity Toolkit Admin com ADC (gcloud)
    if (!kIsWeb && Platform.isWindows) {
      try {
        await _updateAuthViaIdentityToolkitAdmin(
          uid: user.id,
          email: mail,
          password: pass.isEmpty ? null : pass,
          displayName: name,
        );
        await _fs.writeAppUserProfile(
          user.copyWith(
            displayName: name,
            email: mail,
            role: role ?? user.role,
          ),
        );
        await propagateName();
        return null;
      } catch (e) {
        debugPrint('TG_Work: Identity Toolkit admin: $e');
      }

      // 3) Windows: script Node admin-update-user.mjs
      try {
        await _updateViaWindowsAdminScript(
          uid: user.id,
          displayName: name,
          email: mail,
          password: pass.isEmpty ? null : pass,
          role: role,
        );
        await propagateName();
        return null;
      } catch (e) {
        debugPrint('TG_Work: script admin-update-user: $e');
      }
    }

    // 4) Só Firestore (+ email de reposição se pediu password)
    await _fs.writeAppUserProfile(
      user.copyWith(
        displayName: name,
        email: mail,
        role: role ?? user.role,
      ),
    );
    await propagateName();
    if (pass.isNotEmpty) {
      var resetSent = false;
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
        resetSent = true;
      } catch (e) {
        debugPrint('TG_Work: sendPasswordResetEmail: $e');
      }
      if (resetSent) {
        return 'Nome/email guardados. Não dá para definir a password Auth '
            'directamente neste PC (falta Admin SDK / Blaze). '
            'Foi enviado um email de reposição para $mail — o utilizador '
            'abre o link e escolhe a nova password.';
      }
      throw Exception(
        'Nome/email guardados, mas a password Auth não foi alterada. '
        'Instala o Google Cloud SDK e corre «gcloud auth application-default login», '
        'ou pede ao utilizador para usar «Esqueci a password» no login.',
      );
    }
    if (mail != user.email.trim().toLowerCase()) {
      return 'Email actualizado na app. O email de login Auth pode ainda ser '
          'o antigo até haver Admin SDK neste PC (gcloud ADC ou Blaze).';
    }
    return null;
  }

  Future<String?> _updateSelf({
    required AppUser user,
    required String name,
    required String mail,
    required String pass,
    AppUserRole? role,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw StateError('Sem sessão');
    if (name.isNotEmpty && (current.displayName ?? '') != name) {
      await current.updateDisplayName(name);
    }
    if (pass.isNotEmpty) {
      await current.updatePassword(pass);
    }
    final currentEmail = (current.email ?? '').trim().toLowerCase();
    var emailNote = '';
    if (mail != currentEmail) {
      await current.verifyBeforeUpdateEmail(mail);
      emailNote =
          'Enviámos um email de confirmação para $mail (o login muda após confirmares).';
    }
    await current.reload();
    await _fs.writeAppUserProfile(
      user.copyWith(
        displayName: name,
        email: mail,
        role: role ?? user.role,
      ),
    );
    if (name.isNotEmpty) {
      await _fs.updateAppUserDisplayNameAndPropagate(
        uid: user.id,
        displayName: name,
      );
    }
    return emailNote.isEmpty ? null : emailNote;
  }

  Future<void> _updateAuthViaIdentityToolkitAdmin({
    required String uid,
    required String email,
    String? password,
    required String displayName,
  }) async {
    final token = await _gcloudAccessToken();
    final body = <String, dynamic>{
      'localId': uid,
      'email': email,
      'displayName': displayName,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    final res = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:update',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Auth update ${res.statusCode}: ${res.body}');
    }
  }

  Future<String> _gcloudAccessToken() async {
    // 1) gcloud ADC (se instalado)
    try {
      final result = await Process.run(
        'gcloud',
        ['auth', 'application-default', 'print-access-token'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final token = result.stdout.toString().trim();
        if (token.isNotEmpty) return token;
      }
    } catch (e) {
      debugPrint('TG_Work: gcloud ADC: $e');
    }

    // 2) Token do «firebase login» (configstore) — funciona neste PC sem gcloud
    final fromFirebaseCli = await _firebaseToolsAccessToken();
    if (fromFirebaseCli != null && fromFirebaseCli.isNotEmpty) {
      return fromFirebaseCli;
    }

    throw Exception(
      'Sem credenciais admin. No PC: «firebase login» (já usado neste repo) '
      'ou «gcloud auth application-default login».',
    );
  }

  /// Lê o access_token do Firebase CLI (`firebase login`).
  Future<String?> _firebaseToolsAccessToken() async {
    if (kIsWeb) return null;
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final candidates = <String>[
      if (home.isNotEmpty)
        '$home\\.config\\configstore\\firebase-tools.json',
      if (home.isNotEmpty)
        '$home\\AppData\\Roaming\\configstore\\firebase-tools.json',
    ];
    for (final path in candidates) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final tokens = map['tokens'];
        if (tokens is Map) {
          final access = tokens['access_token']?.toString().trim() ?? '';
          if (access.isNotEmpty) return access;
        }
      } catch (e) {
        debugPrint('TG_Work: ler firebase-tools.json: $e');
      }
    }
    return null;
  }

  Future<void> _updateViaWindowsAdminScript({
    required String uid,
    required String displayName,
    required String email,
    String? password,
    AppUserRole? role,
  }) async {
    final script = _resolveAdminScript();
    if (script == null) {
      throw StateError('Script admin-update-user.mjs não encontrado.');
    }
    final args = <String>[
      script,
      '--uid=$uid',
      '--email=$email',
      '--name=$displayName',
      if (password != null && password.isNotEmpty) '--password=$password',
      if (role != null) '--role=${role.key}',
    ];
    final result = await Process.run(
      'node',
      args,
      workingDirectory: File(script).parent.parent.path,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      final err = '${result.stderr}\n${result.stdout}'.trim();
      throw StateError(err.isEmpty ? 'Script admin falhou.' : err);
    }
  }

  String? _resolveAdminScript() {
    final candidates = <String>[
      r'c:\Users\Utilizador\github-repos\TG_Work\tg_work\scripts\admin-update-user.mjs',
      '${Directory.current.path}\\scripts\\admin-update-user.mjs',
      '${File(Platform.resolvedExecutable).parent.path}\\scripts\\admin-update-user.mjs',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }
}
