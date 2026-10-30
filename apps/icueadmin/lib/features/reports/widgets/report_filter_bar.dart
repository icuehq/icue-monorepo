import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
    this.trailing,
    super.key,
  });

  final AppFilterResult currentFilter;
  final ValueChanged<AppFilterResult> onFilterChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await AppDateFilterModal.show(
                  context,
                  initialMode: currentFilter.mode,
                  initialDate: currentFilter.date,
                  initialMonth: currentFilter.month,
                  initialYear: currentFilter.year,
                  initialRange: currentFilter.range,
                );
                if (result != null) {
                  onFilterChanged(result);
                }
              },
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(
                currentFilter.displayLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
