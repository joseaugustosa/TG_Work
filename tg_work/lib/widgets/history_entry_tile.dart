import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/status_change.dart';
import '../utils/user_display.dart';

/// Uma linha do histórico: alteração geral ([kind] audit) ou mudança de estado (legacy).
class HistoryEntryTile extends StatelessWidget {
  final StatusChange change;
  final DateFormat fmt;

  const HistoryEntryTile({
    super.key,
    required this.change,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final actor = auditActorLabel(
      storedDisplayName: change.changedByName,
      uidOrEmpty: change.changedBy,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              change.isAuditEntry ? Icons.edit_note : Icons.swap_horiz,
              size: 18,
              color: const Color(0xFF1A237E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (change.isAuditEntry)
                  Text(
                    change.summaryLine,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusChip(label: change.oldStatusLabel, old: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _StatusChip(label: change.newStatusLabel, old: false),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  actor,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  fmt.format(change.changedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool old;

  const _StatusChip({required this.label, required this.old});

  @override
  Widget build(BuildContext context) {
    final color = old ? Colors.grey[600]! : const Color(0xFF1A237E);
    final text = label.isEmpty ? '—' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
