import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/members/widgets/member_card.dart';
import 'package:school_library/src/ui/members/widgets/member_empty_states.dart';
import 'package:school_library/src/ui/members/widgets/members_table.dart';

/// People who have borrowed (FRS 11.7). Nobody is enrolled here: the ERP is searched at
/// the desk, and a person appears on this list the first time they borrow.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  MemberKind _kind = MemberKind.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadMembers(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _toggleBlock(LibraryMember member) async {
    final libraryProvider = context.read<LibraryProvider>();
    String? reason;
    if (!member.blocked) {
      final reasonController = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Block ${member.label}'),
          content: IcueTextField(
            controller: reasonController,
            maxLength: 500,
            autofocus: true,
            label: 'Reason for blocking',
          ),
          actions: [
            IcueButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(dialogContext),
              variant: IcueButtonVariant.ghost,
            ),
            IcueButton(
              label: 'Block borrower',
              onPressed: () =>
                  Navigator.pop(dialogContext, reasonController.text.trim()),
              variant: IcueButtonVariant.destructive,
            ),
          ],
        ),
      );
      reasonController.dispose();
      if (reason == null || reason.isEmpty) return;
    }
    final saved = await libraryProvider.setMemberBlocked(
      member.id,
      blocked: !member.blocked,
      reason: reason,
    );
    if (!saved && mounted) {
      showMessage(context, libraryProvider.errorMessage ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final allMembers = libraryProvider.members;

    final filteredMembers = allMembers.where((member) {
      if (!_kind.matches(member)) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = member.label.toLowerCase().contains(query);
        final matchErpId = '${member.personErpId}'.contains(query);
        final matchClass =
            member.classId != null && '${member.classId}'.contains(query);
        return matchName || matchErpId || matchClass;
      }
      return true;
    }).toList();

    final isWide = context.isWide;
    final loadMore = libraryProvider.hasMoreMembers
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: IcueButton(
                label: 'Load more',
                onPressed: libraryProvider.membersLoading
                    ? null
                    : () => libraryProvider.loadMembers(more: true),
                variant: IcueButtonVariant.ghost,
              ),
            ),
          )
        : null;

    final kindSelector = DropdownButton<MemberKind>(
      value: _kind,
      underline: const SizedBox.shrink(),
      items: [
        for (final kind in MemberKind.values)
          DropdownMenuItem(value: kind, child: Text(kind.label)),
      ],
      onChanged: (kind) => setState(() => _kind = kind ?? MemberKind.all),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MembersTable(
                      members: allMembers,
                      loading:
                          libraryProvider.membersLoading && allMembers.isEmpty,
                      onToggleBlock: _toggleBlock,
                    ),
                  ),
                  ?loadMore,
                ],
              ),
            )
          : IcueCenteredBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        kindSelector,
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search member name, ID, class…',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value.trim()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: libraryProvider.membersLoading && allMembers.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredMembers.isEmpty
                        ? (allMembers.isEmpty
                              ? const MemberInitialEmptyState()
                              : MemberNoResultsState(
                                  searchQuery: _searchQuery,
                                  onClear: _clearSearch,
                                ))
                        : RefreshIndicator(
                            onRefresh: () => libraryProvider.loadMembers(),
                            child: IcueAdaptiveList<LibraryMember>(
                              items: filteredMembers,
                              columns: [
                                IcueAdaptiveColumn(
                                  label: 'Name',
                                  flex: 3,
                                  cell: (context, member) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        member.isStudent
                                            ? Icons.school_outlined
                                            : Icons.person_outline_rounded,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          member.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IcueAdaptiveColumn.text(
                                  'ERP ID',
                                  (member) => '${member.personErpId}',
                                ),
                                IcueAdaptiveColumn.text(
                                  'Class',
                                  (member) => member.classId == null
                                      ? '—'
                                      : '${member.classId}',
                                ),
                                IcueAdaptiveColumn(
                                  label: 'On loan',
                                  cell: (context, member) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: member.activeLoans > 0
                                          ? theme.colorScheme.primaryContainer
                                                .withValues(alpha: 0.5)
                                          : theme
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${member.activeLoans} books',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: member.activeLoans > 0
                                                ? theme.colorScheme.primary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                                IcueAdaptiveColumn(
                                  label: 'Status',
                                  cell: (context, member) =>
                                      MemberStatusPill(member: member),
                                ),
                                IcueAdaptiveColumn(
                                  label: '',
                                  cell: (context, member) => IconButton(
                                    tooltip: member.blocked
                                        ? 'Unblock'
                                        : 'Block',
                                    icon: Icon(
                                      member.blocked
                                          ? Icons.lock_open_rounded
                                          : Icons.block_rounded,
                                      size: 18,
                                      color: member.blocked
                                          ? Colors.green.shade700
                                          : theme.colorScheme.error,
                                    ),
                                    onPressed: () => _toggleBlock(member),
                                  ),
                                ),
                              ],
                              cardBuilder: (context, member) => MemberCard(
                                member: member,
                                onToggleBlock: () => _toggleBlock(member),
                              ),
                              footer: loadMore,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
