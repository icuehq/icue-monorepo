import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen fines as an [IcueTable]. Search and every filter are Firestore
/// queries (the provider reloads); pages come from its pager.
class FinesTable extends StatelessWidget {
  const FinesTable({required this.onOpen, super.key});

  final void Function(LibraryFine fine) onOpen;

  static const statuses = {
    'outstanding': 'Outstanding',
    'partially_paid': 'Partially paid',
    'paid': 'Paid',
    'waived': 'Waived',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final pager = provider.fines;

    return IcueTable<LibraryFine>(
      title: 'Fines',
      rows: pager.items,
      rowKey: (fine) => fine.id,
      rowLabel: (fine) => fine.id,
      count: pager.total ?? pager.items.length,
      status: IcueTableStatus.pager(pager),
      onRetry: pager.retry,
      pagination: IcueTablePagination.pager(pager),
      onRowTap: onOpen,
      searchHint: 'Fine # or accession no.',
      initialSearch: provider.fineSearch,
      searchDebounce: const Duration(milliseconds: 400),
      onSearchChanged: (query) {
        provider.fineSearch = query.trim();
        provider.loadFines();
      },
      filters: [
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: [
            for (final MapEntry(:key, :value) in statuses.entries)
              IcueTableFilterOption(key, value),
          ],
          value: provider.fineStatus,
          onChanged: (value) {
            provider
              ..fineStatus = value
              ..loadFines();
          },
        ),
        IcueTableFilter(
          id: 'type',
          label: 'Type',
          options: [
            for (final type in const ['overdue', 'lost', 'damaged'])
              IcueTableFilterOption(type, fineTypeLabel(type)),
          ],
          value: provider.fineType,
          onChanged: (value) {
            provider
              ..fineType = value
              ..loadFines();
          },
        ),
      ],
      isFiltered: provider.finesFiltered,
      onClearFilters: provider.clearFineFilters,
      emptyTitle: 'No fines',
      emptyMessage: 'Fines will appear here.',
      columns: [
        IcueTableColumn(
          id: 'book',
          label: 'Book Title',
          flex: 2,
          cellBuilder: (context, fine) =>
              IcueTableCellText(fine.bookTitle ?? fine.barcode ?? '-'),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 3,
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.memberLabel,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'class',
          label: 'Class',
          hideBelowWidth: 900,
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.memberClassId == null
                ? '-'
                : context.watch<LibraryProvider>().className(
                    fine.memberClassId!,
                  ),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'section',
          label: 'Section',
          hideBelowWidth: 900,
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.memberSection ?? '-',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'admission',
          label: 'Admission Number',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.admissionNumber ?? '-',
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
          cellBuilder: (context, fine) =>
              IcueTableCellText(fine.amount.toRupees()),
        ),
        IcueTableColumn(
          id: 'paid',
          label: 'Paid',
          cellBuilder: (context, fine) => IcueTableCellText(
            fine.paid.toRupees(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'due',
          label: 'Due',
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
