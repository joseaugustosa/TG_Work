import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_release_service.dart';

/// Verifica em silêncio e, se houver versão nova, mostra um diálogo com um só botão.
Future<void> checkAndPromptAppUpdate(BuildContext context) async {
  if (kIsWeb) return;
  final service = AppReleaseService();
  try {
    final installed = await service.currentPackageInfo();
    final latest = await service.fetchLatest();
    if (latest == null || !service.isNewer(latest, installed)) return;
    if (!context.mounted) return;

    final url = _urlForDevice(latest);
    if (url == null || url.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Atualização disponível'),
        content: Text(
          'Há uma nova versão (${latest.label}). '
          'A versão instalada é ${installed.version} (${installed.buildNumber}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mais tarde'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  } catch (_) {
    // Silencioso: falha de rede não interrompe a app.
  }
}

String? _urlForDevice(AppReleaseInfo latest) {
  if (Platform.isAndroid && latest.apkUrl.isNotEmpty) return latest.apkUrl;
  if (Platform.isWindows && latest.msiUrl.isNotEmpty) return latest.msiUrl;
  return null;
}
