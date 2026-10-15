import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_release_service.dart';

/// Verifica atualizações automaticamente; só mostra «Atualizar» se houver versão nova.
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
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
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
          _error = 'Não foi possível verificar atualizações agora.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível verificar atualizações.';
      });
    }
  }

  String? _downloadUrlForThisDevice(AppReleaseInfo latest) {
    if (kIsWeb) return null;
    if (Platform.isAndroid && latest.apkUrl.isNotEmpty) return latest.apkUrl;
    if (Platform.isWindows && latest.msiUrl.isNotEmpty) return latest.msiUrl;
    return null;
  }

  Future<void> _applyUpdate() async {
    final latest = _latest;
    if (latest == null) return;
    final url = _downloadUrlForThisDevice(latest);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Atualização não disponível para este dispositivo.',
          ),
        ),
      );
      return;
    }
    setState(() => _updating = true);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar a atualização.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

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
            const Row(
              children: [
                Icon(Icons.system_update_alt, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Atualizações',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Versão instalada: $installedLabel',
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('A verificar atualizações…'),
                  ],
                ),
              )
            else if (_error != null && !hasUpdate)
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              )
            else if (hasUpdate && latest != null) ...[
              Text(
                'Nova versão disponível: ${latest.label}',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _updating ? null : _applyUpdate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: _updating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(_updating ? 'A abrir…' : 'Atualizar'),
              ),
            ] else
              Text(
                latest != null
                    ? 'Está atualizado (${latest.label}).'
                    : 'Está atualizado.',
                style: TextStyle(color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }
}
