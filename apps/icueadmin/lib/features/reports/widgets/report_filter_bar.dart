import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
    this.trailing,
    super.key,
  });

  final IcueFilterResult currentFilter;
  final ValueChanged<IcueFilterResult> onFilterChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: IcueButton(
              label: currentFilter.displayLabel,
              onPressed: () async {
                final result = await IcueDateFilterModal.show(
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
              variant: IcueButtonVariant.outline,
              leadingIcon: Icons.date_range_rounded,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
