import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_release_service.dart';

/// Versão instalada + downloads via GitHub Releases (canal à parte).
class ProfileUpdatesSection extends StatefulWidget {
  const ProfileUpdatesSection({super.key});

  @override
  State<ProfileUpdatesSection> createState() => _ProfileUpdatesSectionState();
}

class _ProfileUpdatesSectionState extends State<ProfileUpdatesSection> {
  final _service = AppReleaseService();
  PackageInfo? _installed;
  AppReleaseInfo? _latest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final installed = await _service.currentPackageInfo();
      final latest = await _service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _latest = latest;
        _loading = false;
        if (latest == null) {
          _error =
              'Ainda não há GitHub Release, ou a rede bloqueou a API. Abre a página de releases.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir: $url')),
      );
    }
  }

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    final installed = _installed;
    final latest = _latest;
    final hasUpdate =
        installed != null && latest != null && _service.isNewer(latest, installed);
    final installedLabel = installed == null
        ? '…'
        : '${installed.version} (${installed.buildNumber})';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt, color: Color(0xFF1A237E)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Versão e atualizações',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  tooltip: 'Verificar no GitHub',
                  onPressed: _loading ? null : _refresh,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Instalada: $installedLabel',
              style: TextStyle(color: Colors.grey[800]),
            ),
            if (latest != null) ...[
              const SizedBox(height: 4),
              Text(
                hasUpdate
                    ? 'Nova release no GitHub: ${latest.label}'
                    : 'Última release: ${latest.label} (atualizado)',
                style: TextStyle(
                  color: hasUpdate ? Colors.orange[800] : Colors.grey[700],
                  fontWeight: hasUpdate ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (latest.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  latest.notes,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 12.5, color: Colors.red[700]),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'APK e MSI vêm do GitHub Releases — canal à parte do código. '
              'Descarregas e instalas no dispositivo.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (_isAndroid || kIsWeb)
              FilledButton.icon(
                onPressed: latest?.apkUrl.isNotEmpty == true
                    ? () => _open(latest!.apkUrl)
                    : () => _open(AppReleaseService.releasesPageUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                ),
                icon: const Icon(Icons.android),
                label: Text(
                  hasUpdate ? 'Descarregar APK (atualizar)' : 'Descarregar APK',
                ),
              ),
            if (_isWindows || kIsWeb) ...[
              if (_isAndroid || kIsWeb) const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: latest?.msiUrl.isNotEmpty == true
                    ? () => _open(latest!.msiUrl)
                    : () => _open(AppReleaseService.releasesPageUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                ),
                icon: const Icon(Icons.desktop_windows_outlined),
                label: Text(
                  hasUpdate
                      ? 'Descarregar MSI (atualizar)'
                      : 'Descarregar MSI (Windows)',
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _open(
                latest?.pageUrl ?? AppReleaseService.releasesPageUrl,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir GitHub Releases'),
            ),
          ],
        ),
      ),
    );
  }
}
