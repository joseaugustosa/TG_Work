import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Metadados do último [GitHub Release](https://github.com/joseaugustosa/TG_Work/releases).
class AppReleaseInfo {
  final String version;
  final int build;
  final String tag;
  final String apkUrl;
  final String msiUrl;
  final String notes;
  final String pageUrl;

  const AppReleaseInfo({
    required this.version,
    required this.build,
    required this.tag,
    required this.apkUrl,
    required this.msiUrl,
    this.notes = '',
    this.pageUrl = AppReleaseService.releasesPageUrl,
  });

  String get label => build > 0 ? '$version ($build)' : version;

  factory AppReleaseInfo.fromGithubRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?)?.trim() ?? '';
    final parsed = _parseTag(tag);
    final assets = (json['assets'] as List?) ?? const [];
    String apk = '';
    String msi = '';
    for (final raw in assets) {
      if (raw is! Map) continue;
      final name = ((raw['name'] as String?) ?? '').toLowerCase();
      final url = (raw['browser_download_url'] as String?)?.trim() ?? '';
      if (url.isEmpty) continue;
      if (name.endsWith('.apk')) apk = url;
      if (name.endsWith('.msi')) msi = url;
    }
    final body = (json['body'] as String?)?.trim() ?? '';
    final htmlUrl = (json['html_url'] as String?)?.trim();
    return AppReleaseInfo(
      version: parsed.version,
      build: parsed.build,
      tag: tag,
      apkUrl: apk,
      msiUrl: msi,
      notes: body,
      pageUrl: (htmlUrl != null && htmlUrl.isNotEmpty)
          ? htmlUrl
          : AppReleaseService.releasesPageUrl,
    );
  }
}

class AppReleaseFetchResult {
  final AppReleaseInfo? info;
  final String errorMessage;

  const AppReleaseFetchResult({this.info, this.errorMessage = ''});
}

class _ParsedTag {
  final String version;
  final int build;
  const _ParsedTag(this.version, this.build);
}

_ParsedTag _parseTag(String tag) {
  var t = tag.trim();
  if (t.startsWith('v') || t.startsWith('V')) {
    t = t.substring(1);
  }
  final plus = t.split('+');
  final version = plus.first.trim();
  final build = plus.length > 1 ? (int.tryParse(plus[1].trim()) ?? 0) : 0;
  return _ParsedTag(version.isEmpty ? tag : version, build);
}

class AppReleaseService {
  static const String githubOwner = 'joseaugustosa';
  static const String githubRepo = 'TG_Work';
  static const String releasesPageUrl =
      'https://github.com/joseaugustosa/TG_Work/releases';
  static const String latestApiUrl =
      'https://api.github.com/repos/joseaugustosa/TG_Work/releases/latest';

  Future<PackageInfo> currentPackageInfo() => PackageInfo.fromPlatform();

  Future<AppReleaseInfo?> fetchLatest() async {
    final r = await fetchLatestDetailed();
    return r.info;
  }

  /// Lê só a API pública do GitHub Releases (repo tem de ser público).
  Future<AppReleaseFetchResult> fetchLatestDetailed() async {
    try {
      final res = await http
          .get(
            Uri.parse(latestApiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'TgWork-App',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        return const AppReleaseFetchResult(
          errorMessage:
              'Não há release no GitHub, ou o repositório não é público.',
        );
      }
      if (res.statusCode != 200) {
        debugPrint('GitHub releases HTTP ${res.statusCode}: ${res.body}');
        return AppReleaseFetchResult(
          errorMessage: 'GitHub respondeu ${res.statusCode}. Tenta outra vez.',
        );
      }
      final map = jsonDecode(res.body);
      if (map is! Map<String, dynamic>) {
        return const AppReleaseFetchResult(
          errorMessage: 'Resposta do GitHub inválida.',
        );
      }
      final info = AppReleaseInfo.fromGithubRelease(map);
      if (info.version.isEmpty && info.tag.isEmpty) {
        return const AppReleaseFetchResult(
          errorMessage: 'Release sem versão legível.',
        );
      }
      return AppReleaseFetchResult(info: info);
    } catch (e, st) {
      debugPrint('AppReleaseService.fetchLatest: $e\n$st');
      return const AppReleaseFetchResult(
        errorMessage: 'Falha de rede ao contactar o GitHub. Tenta outra vez.',
      );
    }
  }

  bool isNewer(AppReleaseInfo latest, PackageInfo installed) {
    final localBuild = int.tryParse(installed.buildNumber) ?? 0;
    if (latest.build > 0 && localBuild > 0) {
      return latest.build > localBuild;
    }
    return _compareSemver(latest.version, installed.version) > 0;
  }

  static int _compareSemver(String a, String b) {
    List<int> parts(String v) {
      final core = v.split('+').first.split('-').first.trim();
      return core
          .split('.')
          .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final pa = parts(a);
    final pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
