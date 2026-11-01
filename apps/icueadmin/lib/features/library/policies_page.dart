import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/policy_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Borrowing policies per library and member category (FRS 11.8).
class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final canEdit = p.access.can('lib.settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Borrowing policies')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => PolicySheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Policy'),
            )
          : null,
      body: p.policies.isEmpty
          ? Center(child: Text(p.isLoading ? 'Loading…' : 'No policies yet'))
          : ListView(
              children: [
                for (final x in p.policies)
                  ListTile(
                    title: Text(x.name),
                    subtitle: Text(
                      '${p.library(x.libraryId)?.name ?? x.libraryId} · '
                      '${x.memberCategory}\n${x.summary}',
                    ),
                    isThreeLine: true,
                    leading: x.active ? null : const InactiveBadge(),
                    onTap: canEdit
                        ? () => PolicySheet.show(context, policy: x)
                        : null,
                    trailing: canEdit
                        ? IconButton(
                            tooltip: x.active ? 'Deactivate' : 'Activate',
                            icon: Icon(
                              x.active
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_rounded,
                            ),
                            onPressed: () async {
                              if (!await p.setPolicyActive(
                                    x.id,
                                    active: !x.active,
                                  ) &&
                                  context.mounted) {
                                invSnack(context, p.errorMessage ?? 'Failed');
                              }
                            },
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
