import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class ReportDataTable extends StatelessWidget {
  const ReportDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
  });

  final List<ReportTableColumn> columns;
  final List<ReportTableRow> rows;
  final ValueChanged<int>? onRowTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: columns.map((col) {
                return Expanded(
                  flex: col.flex,
                  child: Text(
                    col.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                    textAlign: col.align,
                  ),
                );
              }).toList(),
            ),
          ),
          // Rows
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No data',
                  style:
                      TextStyle(color: AppColors.resolveTextTertiary(context)),
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return InkWell(
                onTap: onRowTap != null ? () => onRowTap!(index) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                    ),
                    color: onRowTap != null ? null : null,
                  ),
                  child: Row(
                    children: row.cells.asMap().entries.map((cellEntry) {
                      final cellIndex = cellEntry.key;
                      final cell = cellEntry.value;
                      final align = cellIndex < columns.length
                          ? columns[cellIndex].align
                          : TextAlign.left;
                      return Expanded(
                        flex: cellIndex < columns.length
                            ? columns[cellIndex].flex
                            : 1,
                        child: cell is num
                            ? Text(
                                _formatCell(cell),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      cellEntry.key == row.cells.length - 1
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                                textAlign: align,
                              )
                            : Text(
                                cell?.toString() ?? '—',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      cellEntry.key == row.cells.length - 1
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                                textAlign: align,
                              ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatCell(dynamic value) {
    if (value is double) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }
}

class ReportTableColumn {
  const ReportTableColumn({
    required this.label,
    this.flex = 1,
    this.align = TextAlign.left,
  });

  final String label;
  final int flex;
  final TextAlign align;
}

class ReportTableRow {
  const ReportTableRow({required this.cells});
  final List<dynamic> cells;
}
