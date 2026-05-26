import 'package:flutter/material.dart';

/// Tabuleiro Kanban horizontal: uma coluna por estado; arrastar entre colunas (rato no Windows).
class StatusKanbanBoard<T extends Object, S> extends StatelessWidget {
  final List<S> columns;
  final String Function(S s) labelOf;
  final Color Function(S s) colorOf;
  final S Function(T item) statusOf;
  final List<T> items;
  final Future<void> Function(T item, S newStatus) onItemMoved;
  final Widget Function(BuildContext context, T item) cardBuilder;

  /// Largura fixa por coluna (lista horizontal quando há muitos estados).
  final double columnWidth;

  const StatusKanbanBoard({
    super.key,
    required this.columns,
    required this.labelOf,
    required this.colorOf,
    required this.statusOf,
    required this.items,
    required this.onItemMoved,
    required this.cardBuilder,
    this.columnWidth = 288,
  });

  List<T> _inColumn(S status) =>
      items.where((e) => statusOf(e) == status).toList();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 400.0;
        return SizedBox(
          height: h,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns.map((status) {
                final list = _inColumn(status);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: columnWidth,
                    height: h - 16,
                    child: _KanbanColumn<T, S>(
                      columnStatus: status,
                      label: labelOf(status),
                      headerColor: colorOf(status),
                      items: list,
                      statusOf: statusOf,
                      onItemMoved: onItemMoved,
                      cardBuilder: cardBuilder,
                      columnWidth: columnWidth,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _KanbanColumn<T extends Object, S> extends StatelessWidget {
  final S columnStatus;
  final String label;
  final Color headerColor;
  final List<T> items;
  final S Function(T item) statusOf;
  final Future<void> Function(T item, S newStatus) onItemMoved;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final double columnWidth;

  const _KanbanColumn({
    required this.columnStatus,
    required this.label,
    required this.headerColor,
    required this.items,
    required this.statusOf,
    required this.onItemMoved,
    required this.cardBuilder,
    required this.columnWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(label: label, color: headerColor, count: items.length),
        const SizedBox(height: 8),
        Expanded(
          child: DragTarget<T>(
            onWillAcceptWithDetails: (details) =>
                statusOf(details.data) != columnStatus,
            onAcceptWithDetails: (details) async {
              final item = details.data;
              if (statusOf(item) == columnStatus) return;
              try {
                await onItemMoved(item, columnStatus);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Não foi possível mover: $e')),
                  );
                }
              }
            },
            builder: (context, candidateData, rejectedData) {
              final active = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: active
                      ? headerColor.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? headerColor : Colors.grey.shade300,
                    width: active ? 2 : 1,
                  ),
                ),
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            active
                                ? 'Larga aqui'
                                : 'Sem itens\nArrasta um cartão para aqui',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final card = cardBuilder(context, item);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Draggable<T>(
                              data: item,
                              feedback: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(10),
                                clipBehavior: Clip.antiAlias,
                                child: SizedBox(
                                  width: columnWidth - 16,
                                  child: Opacity(
                                    opacity: 0.95,
                                    child: card,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: card,
                              ),
                              child: card,
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _ColumnHeader({
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color.darken(),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: color.darken(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}
