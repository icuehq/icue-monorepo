import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_member_cell.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Wide-screen members as an [IcueTable]. Search and every filter are Firestore
/// queries (the provider reloads); pages come from its pager.
class MembersTable extends StatelessWidget {
  const MembersTable({required this.onToggleBlock, super.key});

  final void Function(LibraryMember member) onToggleBlock;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final pager = provider.members;

    return IcueTable<LibraryMember>(
      title: 'Members',
      rows: pager.items,
      rowKey: (member) => member.id,
      rowLabel: (member) => member.label,
      count: pager.total ?? pager.items.length,
      status: IcueTableStatus.pager(pager),
      onRetry: pager.retry,
      pagination: IcueTablePagination.pager(pager),
      searchHint: 'ERP ID',
      initialSearch: provider.memberSearch,
      searchDebounce: const Duration(milliseconds: 400),
      onSearchChanged: (query) {
        provider.memberSearch = query.trim();
        provider.loadMembers();
      },
      filters: [
        IcueTableFilter(
          id: 'kind',
          label: 'Kind',
          options: [
            for (final kind in MemberKind.values)
              if (kind != MemberKind.all)
                IcueTableFilterOption(kind.name, kind.label),
          ],
          value: provider.memberKind == MemberKind.all
              ? null
              : provider.memberKind.name,
          onChanged: (value) {
            provider
              ..memberKind = value == null
                  ? MemberKind.all
                  : MemberKind.values.byName(value)
              ..loadMembers();
          },
        ),
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('blocked', 'Blocked'),
            IcueTableFilterOption('active', 'Active'),
          ],
          value: switch (provider.memberBlocked) {
            null => null,
            true => 'blocked',
            false => 'active',
          },
          onChanged: (value) {
            provider
              ..memberBlocked = value == null ? null : value == 'blocked'
              ..loadMembers();
          },
        ),
        IcueTableFilter(
          id: 'onLoan',
          label: 'On loan',
          options: const [IcueTableFilterOption('yes', 'Has books out')],
          value: provider.memberOnLoan ? 'yes' : null,
          onChanged: (value) {
            provider
              ..memberOnLoan = value != null
              ..loadMembers();
          },
        ),
      ],
      isFiltered: provider.membersFiltered,
      onClearFilters: provider.clearMemberFilters,
      emptyTitle: 'No borrowers yet',
      emptyMessage:
          'Members are enrolled automatically when they first borrow '
          'a book from the circulation desk.',
      rowActions: (member) => [
        IcueTableRowAction(
          label: member.blocked ? 'Unblock' : 'Block',
          icon: member.blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          inline: true,
          destructive: !member.blocked,
          onPressed: onToggleBlock,
        ),
      ],
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Name',
          minWidth: 200,
          cellBuilder: (context, member) => LibraryMemberCell(
            name: member.label,
            classLabel: provider.classLabel(member.classId, member.section),
          ),
        ),
        IcueTableColumn(
          id: 'admission',
          label: 'Admission Number',
          hideBelowWidth: 800,
          cellBuilder: (context, member) => IcueTableCellText(
            member.admissionNumber ?? '-',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'onLoan',
          label: 'On loan',
          cellBuilder: (context, member) => IcueTableCellText(
            '${member.activeLoans} ${member.activeLoans == 1 ? 'book' : 'books'}',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 120,
          cellBuilder: (context, member) => MemberStatusPill(member: member),
        ),
      ],
    );
  }
}

class MemberStatusPill extends StatelessWidget {
  const MemberStatusPill({required this.member, super.key});

  final LibraryMember member;

  @override
  Widget build(BuildContext context) =>
      LibraryStatusChip(member.blocked ? 'blocked' : 'active');
}
