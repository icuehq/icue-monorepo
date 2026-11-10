import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen active loans as an [IcueClientTable]; search and the status
/// filter run over the loans loaded so far.
class LoansTable extends StatelessWidget {
  const LoansTable({
    required this.loans,
    required this.loading,
    required this.today,
    required this.onOpen,
    super.key,
  });

  final List<LibraryLoan> loans;
  final bool loading;
  final String today;
  final void Function(LibraryLoan loan) onOpen;

  @override
  Widget build(BuildContext context) {
    return IcueClientTable<LibraryLoan>(
      title: 'Loans',
      items: loans,
      rowKey: (loan) => loan.id,
      rowLabel: (loan) => loan.barcode,
      status: IcueTableStatus.of(failed: false, loading: loading),
      onRowTap: onOpen,
      searchHint: 'Search member, copy, or loan #...',
      searchText: (loan) =>
          '${loan.memberLabel} ${loan.barcode} ${loan.number}',
      initialSort: const IcueTableSort('due'),
      filters: [
        IcueClientFilter<LibraryLoan>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('overdue', 'Overdue'),
            IcueTableFilterOption('dueToday', 'Due today'),
          ],
          matches: (loan, option) => option == 'overdue'
              ? loan.overdueOn(today) > 0
              : loan.dueDate == today,
        ),
      ],
      primaryAction: IcueTableAction(
        label: 'Issue',
        icon: Icons.add_rounded,
        onPressed: () => context.push(LibraryRoutes.libraryIssue),
      ),
      emptyTitle: 'No active loans',
      emptyMessage: 'Issued books will appear here.',
      columns: [
        IcueTableColumn(
          id: 'copy',
          label: 'Copy',
          flex: 2,
          sortable: true,
          comparator: (loan) => loan.barcode,
          cellBuilder: (context, loan) => IcueTableCellText(loan.barcode),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 3,
          sortable: true,
          comparator: (loan) => loan.memberLabel,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.memberLabel,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'number',
          label: 'Loan #',
          hideBelowWidth: 900,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.number,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'issued',
          label: 'Issued',
          sortable: true,
          comparator: (loan) => loan.issuedDate,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.issuedDate.toDisplayDay(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'due',
          label: 'Due',
          sortable: true,
          comparator: (loan) => loan.dueDate,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.dueDate.toDisplayDay(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 110,
          cellBuilder: (context, loan) =>
              _StatusPill(daysLate: loan.overdueOn(today)),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.daysLate});

  final int daysLate;

  @override
  Widget build(BuildContext context) {
    final isLate = daysLate > 0;
    final color = isLate ? Colors.red.shade700 : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isLate ? '$daysLate d late' : 'On time',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
