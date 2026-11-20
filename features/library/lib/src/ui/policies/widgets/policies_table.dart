import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/policies/widgets/policy_dialog.dart';

/// Wide-screen borrowing policies: an [IcueClientTable] over the loaded policies.
class PoliciesTable extends StatelessWidget {
  const PoliciesTable({
    required this.policies,
    required this.onToggleActive,
    super.key,
  });

  final List<LibraryPolicy> policies;
  final void Function(LibraryPolicy policy) onToggleActive;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    String libraryName(LibraryPolicy policy) =>
        provider.library(policy.libraryId)?.name ?? policy.libraryId;
    final libraryIds = {for (final policy in policies) policy.libraryId};
    final textStyle = IcueTableStyle.of(context).secondary;

    IcueTableColumn<LibraryPolicy> numberColumn(
      String id,
      String label,
      num Function(LibraryPolicy policy) value,
      String Function(LibraryPolicy policy) text,
    ) => IcueTableColumn(
      id: id,
      label: label,
      width: 120,
      alignment: Alignment.centerRight,
      sortable: true,
      comparator: value,
      cellBuilder: (context, policy) =>
          Text(text(policy), style: IcueTableStyle.of(context).numeric),
    );

    return IcueClientTable<LibraryPolicy>(
      title: 'Borrowing policies',
      items: policies,
      rowKey: (policy) => policy.id,
      rowLabel: (policy) => policy.name,
      searchHint: 'Search policies...',
      searchText: (policy) =>
          '${policy.name} ${libraryName(policy)} ${provider.policyScope(policy)}',
      onRowTap: (policy) => PolicyDialog.show(context, policy: policy),
      primaryAction: IcueTableAction(
        label: 'Policy',
        icon: Icons.add_rounded,
        onPressed: () => PolicyDialog.show(context),
      ),
      filters: [
        IcueClientFilter<LibraryPolicy>(
          id: 'library',
          label: 'Library',
          options: [
            for (final id in libraryIds)
              IcueTableFilterOption(id, provider.library(id)?.name ?? id),
          ],
          matches: (policy, optionId) => policy.libraryId == optionId,
        ),
        IcueClientFilter<LibraryPolicy>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('active', 'Active'),
            IcueTableFilterOption('inactive', 'Inactive'),
          ],
          matches: (policy, optionId) =>
              (optionId == 'active') == policy.active,
        ),
      ],
      rowActions: (policy) => [
        IcueTableRowAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          inline: true,
          onPressed: (row) => PolicyDialog.show(context, policy: row),
        ),
        IcueTableRowAction(
          label: policy.active ? 'Deactivate' : 'Activate',
          icon: policy.active
              ? Icons.block_outlined
              : Icons.check_circle_outline_rounded,
          inline: true,
          onPressed: onToggleActive,
        ),
      ],
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Policy',
          flex: 2,
          minWidth: 180,
          sortable: true,
          comparator: (policy) => policy.name.toLowerCase(),
          hideable: false,
          cellBuilder: (context, policy) => IcueTableCellText(
            policy.name,
            leading: policy.active ? null : const IcueInactiveBadge(),
          ),
        ),
        IcueTableColumn(
          id: 'library',
          label: 'Library',
          flex: 2,
          cellBuilder: (context, policy) =>
              IcueTableCellText(libraryName(policy), style: textStyle),
        ),
        IcueTableColumn(
          id: 'scope',
          label: 'Applies to',
          flex: 2,
          cellBuilder: (context, policy) =>
              IcueTableCellText(provider.policyScope(policy), style: textStyle),
        ),
        numberColumn(
          'maxBooks',
          'Max books',
          (policy) => policy.maxBooks,
          (policy) => '${policy.maxBooks}',
        ),
        numberColumn(
          'loanDays',
          'Loan days',
          (policy) => policy.loanDays,
          (policy) => '${policy.loanDays}',
        ),
        numberColumn(
          'renewals',
          'Renewals',
          (policy) => policy.maxRenewals,
          (policy) => '${policy.maxRenewals}',
        ),
        numberColumn(
          'fine',
          'Fine / day',
          (policy) => policy.fineAmount,
          (policy) =>
              policy.fineAmount > 0 ? policy.fineAmount.toRupees() : '—',
        ),
      ],
    );
  }
}
