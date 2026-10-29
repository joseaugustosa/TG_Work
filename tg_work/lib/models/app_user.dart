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

  /// Acesso às áreas da app (admin ignora e tem tudo).
  final bool accessProjects;
  final bool accessTree;
  final bool accessIdeAgenda;
  final bool accessSettings;

  /// Se false, só vê [allowedProjectIds].
  final bool accessAllProjects;
  final List<String> allowedProjectIds;

  /// Ver «Tempo e despesa (projeto)» no Perfil (admin ignora).
  /// Por omissão oculto — só admin ou quem o admin permitir.
  final bool accessViewTimeExpense;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName = '',
    this.role = AppUserRole.user,
    this.blocked = false,
    this.deleted = false,
    required this.createdAt,
    this.createdBy = '',
    this.accessProjects = true,
    this.accessTree = true,
    this.accessIdeAgenda = true,
    this.accessSettings = true,
    this.accessAllProjects = true,
    this.allowedProjectIds = const [],
    this.accessViewTimeExpense = false,
  });

  bool get isAdmin => role == AppUserRole.admin && !blocked && !deleted;
  bool get isActive => !blocked && !deleted;

  String get label {
    final n = displayName.trim();
    if (n.isNotEmpty) return n;
    final e = email.trim();
    if (e.isNotEmpty) return e;
    return id;
  }

  bool canOpenProjectsTab() => isAdmin || (isActive && accessProjects);
  bool canOpenTreeTab() => isAdmin || (isActive && accessTree);
  bool canOpenIdeAgendaTab() => isAdmin || (isActive && accessIdeAgenda);
  bool canOpenSettingsTab() => isAdmin || (isActive && accessSettings);

  bool canSeeProject(String projectId) {
    if (isAdmin) return true;
    if (!isActive || !accessProjects) return false;
    if (accessAllProjects) return true;
    return allowedProjectIds.contains(projectId);
  }

  bool canViewTimeAndExpense() =>
      isAdmin || (isActive && accessViewTimeExpense);

  AppUser copyWith({
    String? email,
    String? displayName,
    AppUserRole? role,
    bool? blocked,
    bool? deleted,
    String? createdBy,
    bool? accessProjects,
    bool? accessTree,
    bool? accessIdeAgenda,
    bool? accessSettings,
    bool? accessAllProjects,
    List<String>? allowedProjectIds,
    bool? accessViewTimeExpense,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      blocked: blocked ?? this.blocked,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt,
      createdBy: createdBy ?? this.createdBy,
      accessProjects: accessProjects ?? this.accessProjects,
      accessTree: accessTree ?? this.accessTree,
      accessIdeAgenda: accessIdeAgenda ?? this.accessIdeAgenda,
      accessSettings: accessSettings ?? this.accessSettings,
      accessAllProjects: accessAllProjects ?? this.accessAllProjects,
      allowedProjectIds: allowedProjectIds ?? this.allowedProjectIds,
      accessViewTimeExpense:
          accessViewTimeExpense ?? this.accessViewTimeExpense,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    List<String> ids(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    bool flag(String key, {bool defaultValue = true}) {
      final v = map[key];
      if (v == null) return defaultValue;
      return v == true;
    }

    return AppUser(
      id: id,
      email: (map['email'] as String?)?.trim() ?? '',
      displayName: (map['displayName'] as String?)?.trim() ?? '',
      role: appUserRoleFromKey(map['role'] as String?),
      blocked: map['blocked'] == true,
      deleted: map['deleted'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: (map['createdBy'] as String?) ?? '',
      accessProjects: flag('accessProjects'),
      accessTree: flag('accessTree'),
      accessIdeAgenda: flag('accessIdeAgenda'),
      accessSettings: flag('accessSettings'),
      accessAllProjects: flag('accessAllProjects'),
      allowedProjectIds: ids(map['allowedProjectIds']),
      accessViewTimeExpense:
          flag('accessViewTimeExpense', defaultValue: false),
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
        'accessProjects': accessProjects,
        'accessTree': accessTree,
        'accessIdeAgenda': accessIdeAgenda,
        'accessSettings': accessSettings,
        'accessAllProjects': accessAllProjects,
        'allowedProjectIds': allowedProjectIds,
        'accessViewTimeExpense': accessViewTimeExpense,
      };

  Map<String, dynamic> toAccessPatchMap() => {
        'accessProjects': accessProjects,
        'accessTree': accessTree,
        'accessIdeAgenda': accessIdeAgenda,
        'accessSettings': accessSettings,
        'accessAllProjects': accessAllProjects,
        'allowedProjectIds': allowedProjectIds,
        'accessViewTimeExpense': accessViewTimeExpense,
      };
}
