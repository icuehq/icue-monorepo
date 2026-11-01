import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/member_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Student and teacher members (FRS 11.7). Search is an exact ERP ID lookup.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _search = TextEditingController();
  LibMember? _found;

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

  Future<void> _lookup(String v) async {
    final p = context.read<LibraryProvider>();
    final id = int.tryParse(v.trim());
    if (v.trim().isEmpty) return setState(() => _found = null);
    if (id == null) return invSnack(context, 'Enter an ERP ID');
    final m = await p.member(p.memberType, id);
    if (!mounted) return;
    setState(() => _found = m);
    if (m == null) {
      invSnack(context, 'Not a member yet');
      await MemberSheet.show(context, type: p.memberType, erpId: id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final canEdit = p.access.can('lib.circulation.operate');
    final rows = _found == null ? p.members : [_found!];
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => MemberSheet.show(context, type: p.memberType),
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
                  selected: {p.memberType},
                  onSelectionChanged: (s) {
                    _search.clear();
                    setState(() => _found = null);
                    p.loadMembers(type: s.first);
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
                      p.membersLoading
                          ? 'Loading…'
                          : p.errorMessage ?? 'No members yet',
                    ),
                  )
                : ListView(
                    children: [
                      for (final m in rows) _MemberTile(m, canEdit: canEdit),
                      if (_found == null && p.hasMoreMembers)
                        TextButton(
                          onPressed: p.membersLoading
                              ? null
                              : () => p.loadMembers(more: true),
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
  const _MemberTile(this.m, {required this.canEdit});

  final LibMember m;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.read<LibraryProvider>();
    final noPolicy = [
      for (final l in m.libraryIds)
        if (p.policyFor(l, m.memberCategory)?.active != true)
          p.library(l)?.name ?? l,
    ];
    return ListTile(
      leading: m.active ? null : const InactiveBadge(),
      title: Text(m.label),
      subtitle: Text(
        '${m.memberCategory}'
        '${m.classId == null ? '' : ' · class ${m.classId}'}'
        ' · ${m.start}${m.end == null ? '' : ' → ${m.end}'}'
        '\nLibraries: ${m.libraryIds.map((l) => p.library(l)?.name ?? l).join(', ')}'
        ' · ${m.activeLoans} on loan'
        '${noPolicy.isEmpty ? '' : '\nNo active policy in ${noPolicy.join(', ')}'}',
      ),
      isThreeLine: true,
      onTap: canEdit ? () => MemberSheet.show(context, member: m) : null,
      trailing: canEdit
          ? IconButton(
              tooltip: m.active ? 'Deactivate' : 'Activate',
              icon: Icon(
                m.active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              ),
              onPressed: () async {
                if (!await p.setMemberActive(m.id, active: !m.active) &&
                    context.mounted) {
                  invSnack(context, p.errorMessage ?? 'Failed');
                }
              },
            )
          : null,
    );
  }
}
