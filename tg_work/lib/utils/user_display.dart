import 'package:firebase_auth/firebase_auth.dart';

/// Nome legível para gravar (auditoria): nome de perfil, email, ou etiqueta — nunca o UID.
String firebaseUserDisplayLabel(User? user) {
  if (user == null) return '';
  final dn = user.displayName?.trim();
  // Por vezes o displayName foi mal guardado com o UID; ignorar e usar email.
  if (dn != null && dn.isNotEmpty && !looksLikeFirebaseUid(dn)) return dn;
  final em = user.email?.trim();
  if (em != null && em.isNotEmpty) return em;
  return 'Utilizador';
}

/// Texto para cabeçalhos: "Nome · email" se existirem os dois; senão só um deles.
String firebaseProfileSubtitle(User? user) {
  if (user == null) return '';
  final dn = user.displayName?.trim();
  final em = user.email?.trim() ?? '';
  final nameOk = dn != null && dn.isNotEmpty && !looksLikeFirebaseUid(dn);
  if (nameOk) {
    return em.isNotEmpty ? '$dn · $em' : dn;
  }
  if (em.isNotEmpty) return em;
  return 'Utilizador';
}

/// Ao ler da base: mostra o nome guardado. Se estiver vazio **ou for um UID** (dados antigos
/// com `updatedByName` = uid por engano), não mostra essa cadeia — usa uma etiqueta legível.
String auditActorLabel({
  required String? storedDisplayName,
  required String uidOrEmpty,
}) {
  final n = storedDisplayName?.trim();
  final id = uidOrEmpty.trim();

  if (n != null && n.isNotEmpty && !looksLikeFirebaseUid(n)) {
    return n;
  }
  if ((n != null && n.isNotEmpty && looksLikeFirebaseUid(n)) ||
      (id.isNotEmpty && looksLikeFirebaseUid(id))) {
    return 'Utilizador';
  }
  if (id.isEmpty) return 'Desconhecido';
  return id;
}

/// True se [s] parecer um identificador Firebase (cadeia longa só com letras e números).
bool looksLikeFirebaseUid(String s) {
  if (s.length < 20 || s.length > 128) return false;
  return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(s);
}

/// Garante que nunca gravamos string vazia nem UID como nome do utilizador na auditoria.
String normalizeStoredActorName(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'Utilizador';
  if (looksLikeFirebaseUid(t)) return 'Utilizador';
  return t;
}
