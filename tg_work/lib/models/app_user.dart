import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfil de acesso da app (`app_users/{uid}`).
enum AppUserRole { user, admin }

extension AppUserRoleX on AppUserRole {
  String get key => switch (this) {
        AppUserRole.user => 'user',
        AppUserRole.admin => 'admin',
      };

  String get label => switch (this) {
        AppUserRole.user => 'Utilizador',
        AppUserRole.admin => 'Administrador',
      };
}

AppUserRole appUserRoleFromKey(String? key) {
  switch ((key ?? '').trim()) {
    case 'admin':
      return AppUserRole.admin;
    default:
      return AppUserRole.user;
  }
}

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final AppUserRole role;
  final bool blocked;
  final bool deleted;
  final DateTime createdAt;
  final String createdBy;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName = '',
    this.role = AppUserRole.user,
    this.blocked = false,
    this.deleted = false,
    required this.createdAt,
    this.createdBy = '',
  });

  bool get isAdmin => role == AppUserRole.admin && !blocked && !deleted;
  bool get isActive => !blocked && !deleted;

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      email: (map['email'] as String?)?.trim() ?? '',
      displayName: (map['displayName'] as String?)?.trim() ?? '',
      role: appUserRoleFromKey(map['role'] as String?),
      blocked: map['blocked'] == true,
      deleted: map['deleted'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: (map['createdBy'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'email': email.trim().toLowerCase(),
        'displayName': displayName.trim(),
        'role': role.key,
        'blocked': blocked,
        'deleted': deleted,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
      };
}
