import 'dart:async';

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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<LibraryProvider>().memberSearch,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final libraryProvider = context.read<LibraryProvider>();
      unawaited(libraryProvider.loadStandards());
      unawaited(libraryProvider.loadMembers());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    context.read<LibraryProvider>()
      ..memberSearch = value.trim()
      ..loadMembers();
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<LibraryProvider>().clearMemberFilters();
  }

  Future<void> _toggleBlock(LibraryMember member) async {
    final libraryProvider = context.read<LibraryProvider>();
    String? reason;
    if (!member.blocked) {
      final reasonController = TextEditingController();
      reason = await IcueDialog.show<String>(
        context,
        title: 'Block ${member.label}',
        size: IcueDialogSize.small,
        content: IcueTextField(
          controller: reasonController,
          maxLength: 500,
          autofocus: true,
          label: 'Reason for blocking',
        ),
        secondaryAction: IcueDialogAction(
          label: 'Cancel',
          variant: IcueButtonVariant.ghost,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        primaryAction: IcueDialogAction(
          label: 'Block borrower',
          variant: IcueButtonVariant.destructive,
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pop(reasonController.text.trim()),
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
    final pager = libraryProvider.members;

    final isWide = context.isWide;

    final kindSelector = DropdownButton<MemberKind>(
      value: libraryProvider.memberKind,
      underline: const SizedBox.shrink(),
      items: [
        for (final kind in MemberKind.values)
          DropdownMenuItem(value: kind, child: Text(kind.label)),
      ],
      onChanged: (kind) => libraryProvider
        ..memberKind = kind ?? MemberKind.all
        ..loadMembers(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: MembersTable(onToggleBlock: _toggleBlock),
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
                              hintText: 'ERP ID',
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
                              suffixIcon:
                                  libraryProvider.memberSearch.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        _search('');
                                      },
                                    )
                                  : null,
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _search,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: pager.loading && pager.items.isEmpty
                        ? const IcueSkeletonCardList()
                        : pager.items.isEmpty
                        ? (libraryProvider.membersFiltered
                              ? MemberNoResultsState(
                                  searchQuery: libraryProvider.memberSearch,
                                  onClear: _clearFilters,
                                )
                              : const MemberInitialEmptyState())
                        : RefreshIndicator(
                            onRefresh: libraryProvider.loadMembers,
                            child: IcueAdaptiveCardList(
                              itemCount: pager.items.length,
                              footer: IcueLoadMoreFooter.of(pager),
                              itemBuilder: (context, index) => MemberCard(
                                member: pager.items[index],
                                onToggleBlock: () =>
                                    _toggleBlock(pager.items[index]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
