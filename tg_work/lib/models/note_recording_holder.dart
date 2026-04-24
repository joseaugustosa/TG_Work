/// Estado mutável da gravação de nota num diálogo (antes de gravar no Firestore).
class NoteRecordingHolder {
  NoteRecordingHolder({this.originalUrl});

  final String? originalUrl;
  String? pendingLocalPath;
  bool deleteRecording = false;
}
