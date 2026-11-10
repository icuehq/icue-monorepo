import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen fines as an [IcueClientTable]. The status filter reloads server
/// data, so the page owns it.
class FinesTable extends StatelessWidget {
  const FinesTable({
    required this.fines,
    required this.loading,
    required this.status,
    required this.onStatusChanged,
    required this.onOpen,
    super.key,
  });

  final List<LibraryFine> fines;
  final bool loading;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final void Function(LibraryFine fine) onOpen;

  @override
  Widget build(BuildContext context) {
    return IcueClientTable<LibraryFine>(
      title: 'Fines',
      items: fines,
      rowKey: (fine) => fine.id,
      rowLabel: (fine) => fine.fineNumber,
      status: IcueTableStatus.of(failed: false, loading: loading),
      onRowTap: onOpen,
      searchHint: 'Search member, fine #, or copy...',
      searchText: (fine) =>
          '${fine.memberLabel} ${fine.fineNumber} ${fine.barcode ?? ''}',
      externalFilters: [
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('outstanding', 'Outstanding'),
            IcueTableFilterOption('partially_paid', 'Partially paid'),
            IcueTableFilterOption('paid', 'Paid'),
            IcueTableFilterOption('waived', 'Waived'),
          ],
          value: status == 'all' ? null : status,
          onChanged: (value) => onStatusChanged(value ?? 'all'),
        ),
      ],
      externalFiltersActive: status != 'all',
      onClearExternalFilters: () => onStatusChanged('all'),
      emptyTitle: 'No fines',
      emptyMessage: 'Fines will appear here.',
      columns: [
        IcueTableColumn(
          id: 'number',
          label: 'Fine #',
          flex: 2,
          sortable: true,
          comparator: (fine) => fine.fineNumber,
          cellBuilder: (context, fine) => IcueTableCellText(fine.fineNumber),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 3,
          sortable: true,
          comparator: (fine) => fine.memberLabel,
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.memberLabel,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'type',
          label: 'Type',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, fine) =>
              IcueTableCellText(fineTypeLabel(fine.type)),
        ),
        IcueTableColumn(
          id: 'amount',
          label: 'Total',
          sortable: true,
          comparator: (fine) => fine.amount,
          cellBuilder: (context, fine) =>
              IcueTableCellText(fine.amount.toRupees()),
        ),
        IcueTableColumn(
          id: 'paid',
          label: 'Paid',
          sortable: true,
          comparator: (fine) => fine.paid,
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.paid.toRupees(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'due',
          label: 'Due',
          sortable: true,
          comparator: (fine) => fine.outstanding,
          cellBuilder: (context, fine) =>
              IcueTableCellText(fine.outstanding.toRupees()),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 130,
          cellBuilder: (context, fine) =>
              IcueTableCellText(humanizeStatus(fine.status)),
        ),
      ],
    );
  }
}
