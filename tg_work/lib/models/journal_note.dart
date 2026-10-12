import 'package:cloud_firestore/cloud_firestore.dart';

/// Nota cronológica ligada a um projeto, tema ou desenvolvimento.
enum JournalNoteParent { project, theme, development }

extension JournalNoteParentExt on JournalNoteParent {
  String get firestoreSegment {
    switch (this) {
      case JournalNoteParent.project:
        return 'projects';
      case JournalNoteParent.theme:
        return 'themes';
      case JournalNoteParent.development:
        return 'developments';
    }
  }
}

class JournalNote {
  final String id;
  final String text;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? recordingUrl;

  /// Marcado como feito na árvore do projeto (visto).
  final bool done;

  JournalNote({
    required this.id,
    required this.text,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.recordingUrl,
    this.done = false,
  });

  factory JournalNote.fromMap(Map<String, dynamic> map, String id) {
    return JournalNote(
      id: id,
      text: map['text'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordingUrl: map['recordingUrl'] as String?,
      done: map['done'] == true,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'text': text,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'done': done,
      if (recordingUrl != null) 'recordingUrl': recordingUrl,
    };
  }

  JournalNote copyWith({bool? done}) => JournalNote(
        id: id,
        text: text,
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: createdAt,
        recordingUrl: recordingUrl,
        done: done ?? this.done,
      );
}
