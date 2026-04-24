/// Mensagens legíveis para erros comuns do Firestore na app.
String firestoreHistoryErrorHint(Object? error) {
  final raw = error?.toString() ?? '';
  final s = raw.toLowerCase();
  if (s.contains('permission-denied') || s.contains('permission_denied')) {
    return 'Sem permissão para aceder ao histórico. Na Consola Firebase → Firestore → '
        'Regras, permite leitura e escrita na coleção `status_changes` para utilizadores '
        'autenticados (há um exemplo em `tg_work/firestore.rules` no projeto).';
  }
  if (s.contains('failed-precondition')) {
    return 'O Firestore recusou a consulta ($raw). Verifica índices ou regras.';
  }
  return raw.isEmpty ? 'Erro desconhecido.' : raw;
}

/// Erros ao ler/gravar subcoleções `notes` (projeto / tema / desenvolvimento).
String firestoreJournalNotesErrorHint(Object? error) {
  final raw = error?.toString() ?? '';
  final s = raw.toLowerCase();
  if (s.contains('permission-denied') || s.contains('permission_denied')) {
    return 'Sem permissão para as notas. Na Consola Firebase → Firestore → Regras, '
        'inclui blocos para `projects/{id}/notes`, `themes/{id}/notes` e '
        '`developments/{id}/notes` (exemplo em `tg_work/firestore.rules`) e publica com '
        '`firebase deploy --only firestore:rules`.';
  }
  if (s.contains('failed-precondition')) {
    return 'O Firestore recusou a operação nas notas ($raw).';
  }
  return raw.isEmpty ? 'Erro desconhecido.' : raw;
}
