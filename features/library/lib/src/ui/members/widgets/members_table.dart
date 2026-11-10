import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen members as an [IcueClientTable]; search, sort and the status
/// filter run over the members loaded so far.
class MembersTable extends StatelessWidget {
  const MembersTable({
    required this.members,
    required this.loading,
    required this.onToggleBlock,
    super.key,
  });

  final List<LibraryMember> members;
  final bool loading;
  final void Function(LibraryMember member) onToggleBlock;

  @override
  Widget build(BuildContext context) {
    return IcueClientTable<LibraryMember>(
      title: 'Members',
      items: members,
      rowKey: (member) => member.id,
      rowLabel: (member) => member.label,
      status: IcueTableStatus.of(failed: false, loading: loading),
      searchHint: 'Search member name, ID, class...',
      searchText: (member) =>
          '${member.label} ${member.personErpId} ${member.classId ?? ''}',
      initialSort: const IcueTableSort('name'),
      filters: [
        IcueClientFilter<LibraryMember>(
          id: 'kind',
          label: 'Kind',
          options: [
            for (final kind in MemberKind.values)
              if (kind != MemberKind.all)
                IcueTableFilterOption(kind.name, kind.label),
          ],
          matches: (member, option) =>
              MemberKind.values.byName(option).matches(member),
        ),
        IcueClientFilter<LibraryMember>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('blocked', 'Blocked'),
            IcueTableFilterOption('canBorrow', 'Can borrow'),
          ],
          matches: (member, option) => (option == 'blocked') == member.blocked,
        ),
      ],
      emptyTitle: 'No borrowers yet',
      emptyMessage:
          'Members are enrolled automatically when they first borrow or '
          'reserve a book from the circulation desk.',
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
          flex: 3,
          minWidth: 200,
          sortable: true,
          comparator: (member) => member.label.toLowerCase(),
          cellBuilder: (context, member) => IcueTableCellText(
            member.label,
            leading: Icon(
              member.isStudent
                  ? Icons.school_outlined
                  : Icons.person_outline_rounded,
              size: 16,
              color: IcueTableStyle.of(context).inkMuted,
            ),
          ),
        ),
        IcueTableColumn(
          id: 'erpId',
          label: 'ERP ID',
          sortable: true,
          comparator: (member) => member.personErpId,
          cellBuilder: (context, member) => IcueTableCellText(
            '${member.personErpId}',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'class',
          label: 'Class',
          hideBelowWidth: 800,
          cellBuilder: (context, member) => IcueTableCellText(
            member.classId == null ? '—' : '${member.classId}',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'onLoan',
          label: 'On loan',
          sortable: true,
          comparator: (member) => member.activeLoans,
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

/// Who the members list shows. Staff are the library's `teacher` members.
enum MemberKind {
  all('All'),
  student('Students'),
  staff('Staff');

  const MemberKind(this.label);
  final String label;

  bool matches(LibraryMember member) => switch (this) {
    all => true,
    student => member.isStudent,
    staff => !member.isStudent,
  };
}

class MemberStatusPill extends StatelessWidget {
  const MemberStatusPill({required this.member, super.key});

  final LibraryMember member;

  @override
  Widget build(BuildContext context) {
    final color = member.blocked
        ? Theme.of(context).colorScheme.error
        : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        member.blocked ? 'Blocked' : 'Can borrow',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
