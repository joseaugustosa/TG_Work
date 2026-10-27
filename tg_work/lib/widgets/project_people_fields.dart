import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

/// Responsável (1) + intervenientes (vários) a partir de `app_users`.
class ProjectPeopleFields extends StatelessWidget {
  const ProjectPeopleFields({
    super.key,
    required this.service,
    required this.responsibleUserId,
    required this.intervenientUserIds,
    required this.onResponsibleChanged,
    required this.onIntervenientsChanged,
  });

  final FirestoreService service;
  final String responsibleUserId;
  final List<String> intervenientUserIds;
  final ValueChanged<AppUser?> onResponsibleChanged;
  final ValueChanged<List<AppUser>> onIntervenientsChanged;

  static String labelOf(AppUser u) {
    final name = u.displayName.trim();
    if (name.isNotEmpty) return name;
    final email = u.email.trim();
    if (email.isNotEmpty) return email;
    return u.id;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: service.watchActiveAppUsers(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Erro ao carregar utilizadores: ${snap.error}',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          );
        }
        final users = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (users.isEmpty) {
          return Text(
            'Ainda não há utilizadores na app. Em Definições → Administração, '
            'sincroniza ou cria contas.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          );
        }

        final byId = {for (final u in users) u.id: u};
        AppUser? responsible =
            responsibleUserId.isEmpty ? null : byId[responsibleUserId];
        // Manter seleção mesmo se o user deixou de estar “ativo” na lista.
        if (responsible == null && responsibleUserId.isNotEmpty) {
          responsible = AppUser(
            id: responsibleUserId,
            email: '',
            displayName: '(utilizador)',
            createdAt: DateTime.now(),
          );
        }
        final dropdownUsers = <AppUser>[
          if (responsible != null &&
              !users.any((u) => u.id == responsible!.id))
            responsible!,
          ...users,
        ];

        final selectedIntervenients = <AppUser>[
          for (final id in intervenientUserIds)
            if (byId[id] != null) byId[id]!,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Responsável',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: responsible?.id,
                  hint: const Text('Sem responsável'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem responsável'),
                    ),
                    ...dropdownUsers.map(
                      (u) => DropdownMenuItem<String?>(
                        value: u.id,
                        child: Text(labelOf(u)),
                      ),
                    ),
                  ],
                  onChanged: (id) {
                    if (id == null) {
                      onResponsibleChanged(null);
                      return;
                    }
                    AppUser? picked = byId[id];
                    if (picked == null) {
                      for (final u in dropdownUsers) {
                        if (u.id == id) {
                          picked = u;
                          break;
                        }
                      }
                    }
                    onResponsibleChanged(picked);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Intervenientes',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: users.map((u) {
                final selected =
                    selectedIntervenients.any((s) => s.id == u.id);
                final isResponsible = u.id == responsibleUserId;
                return FilterChip(
                  label: Text(labelOf(u)),
                  selected: selected,
                  onSelected: isResponsible
                      ? null
                      : (v) {
                          final next = [...selectedIntervenients];
                          if (v) {
                            if (!next.any((x) => x.id == u.id)) next.add(u);
                          } else {
                            next.removeWhere((x) => x.id == u.id);
                          }
                          onIntervenientsChanged(next);
                        },
                  tooltip: isResponsible
                      ? 'Já é o responsável'
                      : null,
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
