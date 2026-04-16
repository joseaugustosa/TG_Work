import 'package:firebase_auth/firebase_auth.dart';

/// Nome legível para gravar (auditoria): nome de perfil, email, ou etiqueta — nunca o UID.
String firebaseUserDisplayLabel(User? user) {
  if (user == null) return '';
  final dn = user.displayName?.trim();
  if (dn != null && dn.isNotEmpty) return dn;
  final em = user.email?.trim();
  if (em != null && em.isNotEmpty) return em;
  return 'Utilizador';
}

/// Texto para cabeçalhos: "Nome · email" se existirem os dois; senão só um deles.
String firebaseProfileSubtitle(User? user) {
  if (user == null) return '';
  final dn = user.displayName?.trim();
  final em = user.email?.trim() ?? '';
  if (dn != null && dn.isNotEmpty) {
    return em.isNotEmpty ? '$dn · $em' : dn;
  }
  if (em.isNotEmpty) return em;
  return 'Utilizador';
}

/// Ao ler da base: mostra o nome guardado; se faltar, não expõe o UID (confunde com texto encriptado).
String auditActorLabel({
  required String? storedDisplayName,
  required String uidOrEmpty,
}) {
  final n = storedDisplayName?.trim();
  if (n != null && n.isNotEmpty) return n;
  final id = uidOrEmpty.trim();
  if (id.isEmpty) return 'Desconhecido';
  if (_looksLikeFirebaseUid(id)) return 'Utilizador';
  return id;
}

bool _looksLikeFirebaseUid(String s) {
  if (s.length < 20 || s.length > 128) return false;
  return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(s);
}

/// Garante que nunca gravamos string vazia como nome do utilizador na auditoria.
String normalizeStoredActorName(String raw) {
  final t = raw.trim();
  return t.isNotEmpty ? t : 'Utilizador';
}
