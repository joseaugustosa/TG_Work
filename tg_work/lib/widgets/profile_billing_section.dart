import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project.dart';
import '../models/user_billing_settings.dart';
import '../models/active_work_clock.dart';
import '../services/firestore_service.dart';
import '../utils/billing_calculation.dart';
import '../utils/work_timer_format.dart';

/// Escolha do projeto para contagem de tempo + taxa horária + despesa estimada (Perfil).
class ProfileBillingSection extends StatefulWidget {
  const ProfileBillingSection({super.key});

  @override
  State<ProfileBillingSection> createState() => _ProfileBillingSectionState();
}

class _ProfileBillingSectionState extends State<ProfileBillingSection> {
  final _firestore = FirestoreService();
  final _rateController = TextEditingController();
  final _rateFocus = FocusNode();
  String? _projectId;
  bool _prefsSynced = false;
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  double? _parseRate(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save(
    BuildContext context,
    String uid,
    List<Project> projects,
  ) async {
    String? pid = _projectId;
    if (pid != null && !projects.any((p) => p.id == pid)) {
      pid = null;
      if (mounted) setState(() => _projectId = null);
    }
    final rate = _parseRate(_rateController.text);
    setState(() => _saving = true);
    try {
      await _firestore.setUserBillingSettings(
        uid,
        UserBillingSettings(
          billingProjectId: pid,
          hourlyRateEuros: rate,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências de faturação guardadas.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applySettings(UserBillingSettings s) {
    if (_rateFocus.hasFocus) return;
    _projectId = s.billingProjectId;
    if (s.hourlyRateEuros != null) {
      final v = s.hourlyRateEuros!;
      _rateController.text = v == v.roundToDouble()
          ? v.round().toString()
          : v.toStringAsFixed(2).replaceAll('.', ',');
    } else {
      _rateController.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<UserBillingSettings>(
      stream: _firestore.watchUserBillingSettings(uid),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? const UserBillingSettings();
        if (!_prefsSynced && settingsSnap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _applySettings(settings);
              _prefsSynced = true;
            });
          });
        }

        return StreamBuilder<List<Project>>(
          stream: _firestore.getProjects(),
          builder: (context, projectsSnap) {
            final projects = projectsSnap.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 32),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey[800], size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Tempo e despesa (projeto)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolhe o projeto cujo tempo queres usar para estimar despesa, '
                  'e o valor por hora (€). O tempo é o mesmo da contagem do Kanban: '
                  'desde a criação até agora se o projeto está em curso, ou até à última '
                  'atualização em Concluído / Não exequível.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(
                    _projectId != null &&
                            projects.any((p) => p.id == _projectId)
                        ? _projectId
                        : 'none',
                  ),
                  initialValue: _projectId != null &&
                          projects.any((p) => p.id == _projectId)
                      ? _projectId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Projeto a contabilizar',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Nenhum —'),
                    ),
                    ...projects.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _projectId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rateController,
                  focusNode: _rateFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor por hora (€)',
                    hintText: 'ex. 35 ou 35,50',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.euro_outlined),
                  ),
                  onChanged: (_) {},
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(context, uid, projects),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar faturação'),
                  ),
                ),
                if (_projectId != null && _projectId!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  StreamBuilder<Project?>(
                    stream: _firestore.watchProject(_projectId!),
                    builder: (context, pSnap) {
                      final project = pSnap.data;
                      if (project == null) {
                        return Text(
                          'Projeto já não existe. Escolhe outro ou remove a seleção.',
                          style: TextStyle(color: Colors.orange[800], fontSize: 13),
                        );
                      }
                      return StreamBuilder<int>(
                        stream: _firestore.watchProjectWorkedSeconds(uid, project.id),
                        builder: (context, wsnap) {
                          final stored = wsnap.data ?? 0;

                          return StreamBuilder<ActiveWorkClock?>(
                            stream: _firestore.watchActiveWorkClock(uid),
                            builder: (context, cSnap) {
                              final clock = cSnap.data;
                              final activeHere =
                                  clock?.projectId == project.id;

                              int workedTotal(int tick) {
                                if (!activeHere || clock == null) {
                                  return stored;
                                }
                                final seg = DateTime.now()
                                    .difference(clock.segmentStartedAt)
                                    .inSeconds
                                    .clamp(0, 8640000);
                                return stored + seg;
                              }

                              Widget cardBody(int tick, int totalSecs) {
                                final r = _parseRate(_rateController.text) ??
                                    settings.hourlyRateEuros ??
                                    0;
                                final dur = billingDurationForProject(project);
                                final expDates = estimatedExpenseEuros(dur, r);
                                final expClock =
                                    estimatedExpenseEuros(Duration(seconds: totalSecs), r);

                                return Card(
                                  elevation: 0,
                                  color: const Color(0xFFE8EAF6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          project.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tempo no workspace (por datas do projeto): '
                                          '${describeBillingDurationShort(dur)} '
                                          '(${projectIsClosedForBilling(project) ? 'fechado' : 'a decorrer'})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tempo com o relógio TG Work: '
                                          '${formatWorkDurationSeconds(totalSecs)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[900],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          r > 0
                                              ? 'Despesa (datas): ${formatEurosPt(expDates)}\n'
                                                  'Despesa (relógio): ${formatEurosPt(expClock)}'
                                              : 'Define um valor por hora acima para ver despesa estimada.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: r > 0
                                                ? const Color(0xFF1A237E)
                                                : Colors.grey[700],
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (activeHere && clock != null) {
                                return StreamBuilder<int>(
                                  stream: Stream.periodic(
                                    const Duration(seconds: 1),
                                    (i) => i,
                                  ),
                                  initialData: 0,
                                  builder: (context, tk) {
                                    final t = workedTotal(tk.data ?? 0);
                                    return cardBody(tk.data ?? 0, t);
                                  },
                                );
                              }
                              return cardBody(0, workedTotal(0));
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
