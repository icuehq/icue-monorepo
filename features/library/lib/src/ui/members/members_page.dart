import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/members/widgets/member_sheet.dart';

/// Student and teacher members (FRS 11.7). Search is an exact ERP ID lookup.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _search = TextEditingController();
  LibraryMember? _found;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadMembers(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _lookup(String value) async {
    final libraryProvider = context.read<LibraryProvider>();
    final id = int.tryParse(value.trim());
    if (value.trim().isEmpty) return setState(() => _found = null);
    if (id == null) return showMessage(context, 'Enter an ERP ID');
    final member = await libraryProvider.member(libraryProvider.memberType, id);
    if (!mounted) return;
    setState(() => _found = member);
    if (member == null) {
      showMessage(context, 'Not a member yet');
      await MemberSheet.show(
        context,
        type: libraryProvider.memberType,
        personErpId: id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.circulation.operate');
    final rows = _found == null ? libraryProvider.members : [_found!];
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () =>
                  MemberSheet.show(context, type: libraryProvider.memberType),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Member'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'student', label: Text('Students')),
                    ButtonSegment(value: 'teacher', label: Text('Teachers')),
                  ],
                  selected: {libraryProvider.memberType},
                  onSelectionChanged: (values) {
                    _search.clear();
                    setState(() => _found = null);
                    libraryProvider.loadMembers(type: values.first);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Find by ERP ID',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onSubmitted: _lookup,
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      libraryProvider.membersLoading
                          ? 'Loading…'
                          : libraryProvider.errorMessage ?? 'No members yet',
                    ),
                  )
                : ListView(
                    children: [
                      for (final member in rows)
                        _MemberTile(member, canEdit: canEdit),
                      if (_found == null && libraryProvider.hasMoreMembers)
                        TextButton(
                          onPressed: libraryProvider.membersLoading
                              ? null
                              : () => libraryProvider.loadMembers(more: true),
                          child: const Text('Load more'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile(this.member, {required this.canEdit});

  final LibraryMember member;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    final noPolicy = [
      for (final libraryId in member.libraryIds)
        if (libraryProvider
                .policyFor(libraryId, member.memberCategory)
                ?.active !=
            true)
          libraryProvider.library(libraryId)?.name ?? libraryId,
    ];
    return ListTile(
      leading: member.active ? null : const InactiveBadge(),
      title: Text(member.label),
      subtitle: Text(
        '${member.memberCategory}'
        '${member.classId == null ? '' : ' · class ${member.classId}'}'
        ' · ${member.start}${member.end == null ? '' : ' → ${member.end}'}'
        '\nLibraries: ${member.libraryIds.map((libraryId) => libraryProvider.library(libraryId)?.name ?? libraryId).join(', ')}'
        ' · ${member.activeLoans} on loan'
        '${noPolicy.isEmpty ? '' : '\nNo active policy in ${noPolicy.join(', ')}'}',
      ),
      isThreeLine: true,
      onTap: canEdit ? () => MemberSheet.show(context, member: member) : null,
      trailing: canEdit
          ? IconButton(
              tooltip: member.active ? 'Deactivate' : 'Activate',
              icon: Icon(
                member.active
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
              ),
              onPressed: () async {
                if (!await libraryProvider.setMemberActive(
                      member.id,
                      active: !member.active,
                    ) &&
                    context.mounted) {
                  showMessage(
                    context,
                    libraryProvider.errorMessage ?? 'Failed',
                  );
                }
              },
            )
          : null,
    );
  }
}
