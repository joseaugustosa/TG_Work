import '../models/app_user.dart';

/// Mapa uid → rótulo actual (nome, senão email).
Map<String, String> appUserDisplayNamesById(Iterable<AppUser> users) {
  final map = <String, String>{};
  for (final u in users) {
    final name = u.displayName.trim();
    if (name.isNotEmpty) {
      map[u.id] = name;
      continue;
    }
    final email = u.email.trim();
    if (email.isNotEmpty) {
      map[u.id] = email;
    }
  }
  return map;
}
