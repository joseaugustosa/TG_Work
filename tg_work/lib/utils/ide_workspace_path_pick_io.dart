import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

Future<String?> _readWindowsShortcutTarget(String lnkPath) async {
  final escaped = lnkPath.replaceAll("'", "''");
  final command =
      r'$sh = New-Object -ComObject WScript.Shell; $sc = $sh.CreateShortcut('
      "'$escaped'"
      r'); $sc.TargetPath';
  try {
    final r = await Process.run(
      'powershell',
      ['-NoProfile', '-STA', '-Command', command],
      runInShell: false,
    );
    if (r.exitCode != 0) return null;
    final out = '${r.stdout}'.trim();
    if (out.isEmpty) return null;
    return out;
  } catch (_) {
    return null;
  }
}

/// Normaliza o caminho depois da escolha (atalhos .lnk no Windows seguem para o destino).
Future<String> _finalizePickedFilesystemPath(String raw) async {
  final p = raw.trim();
  if (p.isEmpty) return '';

  final ext = path.extension(p).toLowerCase();
  if (!Platform.isWindows) return path.normalize(p);

  if (ext == '.lnk') {
    final target = await _readWindowsShortcutTarget(p);
    if (target != null && target.trim().isNotEmpty) {
      return path.normalize(target.trim());
    }
  }

  return path.normalize(p);
}

Future<_PickKind?> _askPickKind(BuildContext context) async {
  return showDialog<_PickKind>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Seleccionar no computador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Escolha como indicar onde abres este projeto para a extensão IDE '
            '(pasta na raíz, ficheiro .code-workspace, atalho, ou programa).',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.folder_outlined),
            label: const Text('Pasta'),
            onPressed: () => Navigator.pop(ctx, _PickKind.folder),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.insert_drive_file_outlined),
            label: const Text('Ficheiro (.code-workspace, .lnk, .exe, …)'),
            onPressed: () => Navigator.pop(ctx, _PickKind.file),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

enum _PickKind { folder, file }

/// Caminho apto para [Project.ideCountingFolderFsPath] após o utilizador seleccionar no disco.
///
/// Pasta, ficheiro `.code-workspace`, atalhos `.lnk` (no Windows resolve o destino) ou outros
/// ficheiros escolhidos. Em Web devolve sempre `null` (usa o ficheiro-stub).
Future<String?> pickIdeWorkspaceFilesystemPath(BuildContext context) async {
  final kind = await _askPickKind(context);
  if (kind == null || !context.mounted) return null;

  String? picked;
  switch (kind) {
    case _PickKind.folder:
      picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Pasta do workspace IDE',
      );
    case _PickKind.file:
      final res = await FilePicker.pickFiles(
        dialogTitle: 'Workspace, atalho ou executável',
        type: FileType.custom,
        allowedExtensions: const [
          'code-workspace',
          'lnk',
          'exe',
        ],
        allowMultiple: false,
      );
      if (res != null && res.files.isNotEmpty) {
        picked = res.files.single.path;
      }
  }

  if (picked == null || picked.trim().isEmpty) return null;

  final finalized = await _finalizePickedFilesystemPath(picked);
  if (finalized.isEmpty) return null;

  if (context.mounted && path.extension(finalized).toLowerCase() == '.exe') {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('.exe seleccionado'),
        content: const Text(
          'Guardámos o caminho do programa. Para a extensão TG Work IDE contar bem o tempo '
          '(abrir/fechar sessão num repositório), costuma funcionar melhor uma pasta ou um '
          'ficheiro .code-workspace.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok')),
        ],
      ),
    );
  }

  return finalized;
}
