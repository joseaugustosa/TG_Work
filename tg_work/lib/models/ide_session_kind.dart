/// Tipo de sessão de trabalho (IDE automática ou manual).
///
/// Valores gravados no campo `editor` de `user_ide_session_logs`
/// (compatível com a extensão VS Code/Cursor).
enum IdeSessionKind {
  vscode,
  cursor,
  montagemHardware,
  montagemFisica,
}

extension IdeSessionKindX on IdeSessionKind {
  /// Valor persistido em Firestore / extensão.
  String get storageKey {
    switch (this) {
      case IdeSessionKind.vscode:
        return 'vscode';
      case IdeSessionKind.cursor:
        return 'cursor';
      case IdeSessionKind.montagemHardware:
        return 'montagem_hardware';
      case IdeSessionKind.montagemFisica:
        return 'montagem_fisica';
    }
  }

  String get labelPt {
    switch (this) {
      case IdeSessionKind.vscode:
        return 'VS Code';
      case IdeSessionKind.cursor:
        return 'Cursor';
      case IdeSessionKind.montagemHardware:
        return 'Montagem hardware';
      case IdeSessionKind.montagemFisica:
        return 'Montagem física';
    }
  }
}

IdeSessionKind? ideSessionKindFromStorage(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'vscode':
    case 'vscode_insiders':
      return IdeSessionKind.vscode;
    case 'cursor':
      return IdeSessionKind.cursor;
    case 'montagem_hardware':
    case 'montagem hardware':
      return IdeSessionKind.montagemHardware;
    case 'montagem_fisica':
    case 'montagem física':
    case 'montagem fisica':
      return IdeSessionKind.montagemFisica;
    default:
      return null;
  }
}

/// Rótulo legível para qualquer valor `editor` (inclui tipos manuais e IDE).
String ideSessionEditorLabelPt(String editor) {
  final kind = ideSessionKindFromStorage(editor);
  if (kind != null) return kind.labelPt;
  final t = editor.trim();
  return t.isEmpty ? 'Sessão' : t;
}

/// Tipos escolhíveis ao inserir sessão manual.
const List<IdeSessionKind> kManualIdeSessionKinds = IdeSessionKind.values;
