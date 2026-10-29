import 'package:cloud_firestore/cloud_firestore.dart';

/// Segmento registado quando se fecha um workspace na IDE (VS Code / Cursor, etc.).
class IdeSessionLog {
  final String id;
  final String userId;
  /// Email / nome gravados pela extensão no login Firebase (identificação).
  final String userEmail;
  final String userDisplayName;
  final String workspaceRoot;
  final String workspaceName;

  /// ID do projeto Firestore quando existe `.tgwork/project.json`.
  final String tgProjectId;
  final String editor;
  final DateTime openedAt;
  final DateTime closedAt;
  final int durationSeconds;

  /// `manual` quando criada na app; vazio/outro = extensão IDE.
  final String source;

  IdeSessionLog({
    required this.id,
    required this.userId,
    this.userEmail = '',
    this.userDisplayName = '',
    required this.workspaceRoot,
    required this.workspaceName,
    required this.tgProjectId,
    required this.editor,
    required this.openedAt,
    required this.closedAt,
    required this.durationSeconds,
    this.source = '',
  });

  bool get isManual => source.trim() == 'manual';

  String get userLabel {
    final n = userDisplayName.trim();
    if (n.isNotEmpty) return n;
    final e = userEmail.trim();
    if (e.isNotEmpty) return e;
    return userId;
  }

  IdeSessionLog copyWith({String? tgProjectId}) => IdeSessionLog(
        id: id,
        userId: userId,
        userEmail: userEmail,
        userDisplayName: userDisplayName,
        workspaceRoot: workspaceRoot,
        workspaceName: workspaceName,
        tgProjectId: tgProjectId ?? this.tgProjectId,
        editor: editor,
        openedAt: openedAt,
        closedAt: closedAt,
        durationSeconds: durationSeconds,
        source: source,
      );

  static DateTime localCalendarDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static IdeSessionLog? fromFirestore(String docId, Map<String, dynamic> m) {
    final uidRaw = m['userId'];
    final uid = uidRaw is String
        ? uidRaw.trim()
        : (uidRaw == null ? '' : uidRaw.toString().trim());
    if (uid.isEmpty) return null;

    DateTime ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final dur = m['durationSeconds'];
    final seconds = _readDurationSeconds(dur);

    return IdeSessionLog(
      id: docId,
      userId: uid,
      userEmail: (m['userEmail'] as String?)?.trim() ?? '',
      userDisplayName: (m['userDisplayName'] as String?)?.trim() ?? '',
      workspaceRoot: (m['workspaceRoot'] as String?) ?? '',
      workspaceName: (m['workspaceName'] as String?) ?? '',
      tgProjectId: (m['tgProjectId'] as String?) ?? '',
      editor: (m['editor'] as String?) ?? '',
      openedAt: ts(m['openedAt']),
      closedAt: ts(m['closedAt']),
      durationSeconds: seconds,
      source: (m['source'] as String?) ?? '',
    );
  }

  /// Aceita int, double/String numérica (REST / migrações manuais).
  static int _readDurationSeconds(dynamic dur) {
    if (dur is int) return dur;
    if (dur is double) return dur.round();
    if (dur is num) return dur.toInt();
    if (dur is String) {
      return int.tryParse(dur.trim()) ?? 0;
    }
    return 0;
  }
}

/// Resultado da leitura de `user_ide_session_logs`: inclui stubs (`durationSeconds == 0`).
class IdeSessionLogsQuerySnapshot {
  const IdeSessionLogsQuerySnapshot({
    required this.allParsedSessions,
    required this.completedSessions,
    required this.queriedDocumentCount,
    required this.hitQueryLimit,
  });

  /// Tudo o que a app conseguiu interpretar (inclui pendentes com 0 s até o PATCH ao fechar).
  final List<IdeSessionLog> allParsedSessions;

  /// Só fechadas com duração > 0 — usado em relatório, gráfico e Kanban.
  final List<IdeSessionLog> completedSessions;

  /// Documentos devolvidos pelo Firestore com o `limit` actual.
  final int queriedDocumentCount;

  /// `true` se o snapshot tem tantos docs como o limite pedido — pode haver mais por paginar/causar starvation de stubs.
  final bool hitQueryLimit;

  static const empty = IdeSessionLogsQuerySnapshot(
    allParsedSessions: [],
    completedSessions: [],
    queriedDocumentCount: 0,
    hitQueryLimit: false,
  );

  bool get hasOnlyStubsOrZeroDuration =>
      queriedDocumentCount > 0 &&
      completedSessions.isEmpty &&
      allParsedSessions.isNotEmpty;

  /// Documentos chegaram do Firestore mas nenhum passou em `fromFirestore`.
  bool get hasUnreadableFirestoreDocs =>
      queriedDocumentCount > 0 && allParsedSessions.isEmpty;
}
