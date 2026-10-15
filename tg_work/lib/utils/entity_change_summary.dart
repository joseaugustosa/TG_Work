import '../models/project.dart';
import '../models/theme_item.dart';
import '../models/development.dart';

/// Resumo em português das diferenças entre versões; `null` se não houver alteração de conteúdo.
String? summarizeProjectEdit(Project old, Project next) {
  final p = <String>[];
  if (old.name != next.name) p.add('nome');
  if (old.description != next.description) p.add('descrição');
  if (old.descriptionRecordingUrl != next.descriptionRecordingUrl) {
    p.add('gravação da nota');
  }
  if (old.status != next.status) {
    p.add('estado (${old.status.label} → ${next.status.label})');
  }
  if (old.ideCountingFolderFsPath.trim() != next.ideCountingFolderFsPath.trim()) {
    p.add('pasta IDE / tempo');
  }
  if (old.projectTypeId.trim() != next.projectTypeId.trim() ||
      old.projectTypeName.trim() != next.projectTypeName.trim()) {
    p.add('tipo');
  }
  if (old.projectSubtypeId.trim() != next.projectSubtypeId.trim() ||
      old.projectSubtypeName.trim() != next.projectSubtypeName.trim()) {
    p.add('subtipo');
  }
  if (p.isEmpty) return null;
  return 'Alteração: ${p.join('; ')}';
}

String? summarizeThemeEdit(ThemeItem old, ThemeItem next) {
  final p = <String>[];
  if (old.name != next.name) p.add('nome');
  if (old.description != next.description) p.add('descrição');
  if (old.descriptionRecordingUrl != next.descriptionRecordingUrl) {
    p.add('gravação da nota');
  }
  if (old.status != next.status) {
    p.add('estado (${old.status.label} → ${next.status.label})');
  }
  if (p.isEmpty) return null;
  return 'Alteração: ${p.join('; ')}';
}

String? summarizeDevelopmentEdit(Development old, Development next) {
  final p = <String>[];
  if (old.name != next.name) p.add('nome');
  if (old.description != next.description) p.add('descrição');
  if (old.descriptionRecordingUrl != next.descriptionRecordingUrl) {
    p.add('gravação da nota');
  }
  if (old.status != next.status) {
    p.add('estado (${old.status.label} → ${next.status.label})');
  }
  if (p.isEmpty) return null;
  return 'Alteração: ${p.join('; ')}';
}
