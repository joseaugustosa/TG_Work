import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/project.dart';
import '../services/firestore_service.dart';
import '../utils/work_timer_format.dart';

/// Totais de horas IDE (+ timer) para um utilizador, por projeto.
class UserHoursPanel extends StatelessWidget {
  const UserHoursPanel({
    super.key,
    required this.user,
    required this.service,
    this.title,
    this.asCard = false,
  });

  final AppUser user;
  final FirestoreService service;
  final String? title;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: service.watchIdeSecondsByProjectForUser(user.id),
      builder: (context, ideSnap) {
        return StreamBuilder<Map<String, int>>(
          stream: service.watchAllProjectWorkedSeconds(user.id),
          builder: (context, timerSnap) {
            return StreamBuilder<List<Project>>(
              stream: service.getProjects(),
              builder: (context, projSnap) {
                final ideByProject = ideSnap.data ?? {};
                final timerByProject = timerSnap.data ?? {};
                final projects = {
                  for (final p in projSnap.data ?? const <Project>[]) p.id: p,
                };

                final ids = <String>{
                  ...ideByProject.keys,
                  ...timerByProject.keys,
                }.toList()
                  ..sort((a, b) {
                    final na = a == '__sem_projeto__'
                        ? 'Sem projeto'
                        : (projects[a]?.name ?? a);
                    final nb = b == '__sem_projeto__'
                        ? 'Sem projeto'
                        : (projects[b]?.name ?? b);
                    return na.toLowerCase().compareTo(nb.toLowerCase());
                  });

                final ideTotal =
                    ideByProject.values.fold<int>(0, (a, b) => a + b);
                final timerTotal =
                    timerByProject.values.fold<int>(0, (a, b) => a + b);
                final grand = ideTotal + timerTotal;

                final body = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title ?? 'Horas de ${user.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total: ${formatWorkDurationSeconds(grand)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IDE: ${formatWorkDurationSeconds(ideTotal)}'
                      '${timerTotal > 0 ? ' · Relógio: ${formatWorkDurationSeconds(timerTotal)}' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Por projeto',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (ids.isEmpty)
                      Text(
                        'Ainda sem tempo registado.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      ...ids.map((id) {
                        final ide = ideByProject[id] ?? 0;
                        final timer = timerByProject[id] ?? 0;
                        final name = id == '__sem_projeto__'
                            ? 'Sem projeto ligado'
                            : (projects[id]?.name ?? id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                formatWorkDurationSeconds(ide + timer),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );

                if (!asCard) return body;
                return Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: body,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Cartão com sumatório de horas IDE por utilizador (visão admin).
class UsersHoursSummaryCard extends StatelessWidget {
  const UsersHoursSummaryCard({
    super.key,
    required this.service,
    required this.users,
  });

  final FirestoreService service;
  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: service.watchIdeSecondsByUser(),
      builder: (context, snap) {
        final byUser = snap.data ?? {};
        final rows = [...users]..sort((a, b) {
            final sa = byUser[a.id] ?? 0;
            final sb = byUser[b.id] ?? 0;
            return sb.compareTo(sa);
          });
        final total = byUser.values.fold<int>(0, (a, b) => a + b);

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(),
              const Text(
                'Sumário horas IDE por utilizador',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${formatWorkDurationSeconds(total)}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              if (snap.hasError)
                Text(
                  'Erro: ${snap.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                )
              else if (!snap.hasData)
                const LinearProgressIndicator(minHeight: 2)
              else
                ...rows.map((u) {
                  final secs = byUser[u.id] ?? 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(u.label),
                    subtitle:
                        Text(u.email, style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      formatWorkDurationSeconds(secs),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
