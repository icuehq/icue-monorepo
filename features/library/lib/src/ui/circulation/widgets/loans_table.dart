import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen active loans as an [IcueTable]. Search and every filter are
/// Firestore queries (the provider reloads); pages come from its pager.
class LoansTable extends StatelessWidget {
  const LoansTable({required this.today, required this.onOpen, super.key});

  final String today;
  final void Function(LibraryLoan loan) onOpen;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final pager = provider.loans;
    final standard = provider.standards
        .where((standard) => standard.id == provider.loanClassId)
        .firstOrNull;

    return IcueTable<LibraryLoan>(
      title: 'Issued Books',
      rows: pager.items,
      rowKey: (loan) => loan.id,
      rowLabel: (loan) => loan.bookLabel,
      count: pager.total ?? pager.items.length,
      status: IcueTableStatus.pager(pager),
      onRetry: pager.retry,
      pagination: IcueTablePagination.pager(pager),
      onRowTap: onOpen,
      searchHint: 'Loan #, accession no. or admission no.',
      initialSearch: provider.loanSearch,
      searchDebounce: const Duration(milliseconds: 400),
      onSearchChanged: (query) {
        provider.loanSearch = query.trim();
        provider.loadLoans();
      },
      filters: [
        IcueTableFilter(
          id: 'class',
          label: 'Class',
          options: [
            for (final standard in provider.standards)
              IcueTableFilterOption('${standard.id}', standard.name),
          ],
          value: standard == null ? null : '${standard.id}',
          onChanged: (value) {
            provider
              ..loanClassId = value == null ? null : int.parse(value)
              ..loanSection = null
              ..loadLoans();
          },
        ),
        if (standard != null && standard.sections.isNotEmpty)
          IcueTableFilter(
            id: 'section',
            label: 'Section',
            options: [
              for (final section in standard.sections)
                IcueTableFilterOption(section.name, section.name),
            ],
            value: provider.loanSection,
            onChanged: (value) {
              provider
                ..loanSection = value
                ..loadLoans();
            },
          ),
        IcueTableFilter(
          id: 'issued',
          label: 'Issued',
          options: [
            for (final window in LoanIssuedWindow.values)
              IcueTableFilterOption(window.name, window.label),
          ],
          value: provider.loanIssued?.name,
          onChanged: (value) {
            provider
              ..loanIssued = value == null
                  ? null
                  : LoanIssuedWindow.values.byName(value)
              ..loadLoans();
          },
        ),
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: [
            for (final due in LoanDueFilter.values)
              IcueTableFilterOption(due.name, due.label),
          ],
          value: provider.loanDue?.name,
          onChanged: (value) {
            provider
              ..loanDue = value == null
                  ? null
                  : LoanDueFilter.values.byName(value)
              ..loadLoans();
          },
        ),
      ],
      isFiltered: provider.loansFiltered,
      onClearFilters: provider.clearLoanFilters,
      primaryAction: IcueTableAction(
        label: 'Issue',
        icon: Icons.add_rounded,
        onPressed: () => context.push(LibraryRoutes.libraryIssue),
      ),
      emptyTitle: 'No active loans',
      emptyMessage: 'Issued books will appear here.',
      columns: [
        IcueTableColumn(
          id: 'book',
          label: 'Book Title',
          flex: 2,
          cellBuilder: (context, loan) => IcueTableCellText(loan.bookLabel),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 2,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.memberLabel,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'class',
          label: 'Class',
          hideBelowWidth: 900,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.memberClass ?? '-',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'section',
          label: 'Section',
          hideBelowWidth: 900,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.memberSection ?? '-',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'admission',
          label: 'Admission Number',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.admissionNumber ?? '-',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'issued',
          label: 'Issued',
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.issuedDate.toDisplayDay(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'due',
          label: 'Due',
          cellBuilder: (context, loan) => IcueTableCellText(
            loan.dueDate.toDisplayDay(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 110,
          cellBuilder: (context, loan) => _lateness(loan.overdueOn(today)),
        ),
      ],
    );
  }
}

Widget _lateness(int daysLate) => IcueStatusPill(
  label: daysLate > 0 ? '$daysLate d late' : 'On time',
  color: daysLate > 0 ? Colors.red.shade700 : Colors.green.shade700,
  compact: true,
);
