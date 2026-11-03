import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/policies/widgets/policy_sheet.dart';

/// Borrowing policies per library and member category (FRS 11.8).
class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Borrowing policies')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => PolicySheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Policy'),
            )
          : null,
      body: libraryProvider.policies.isEmpty
          ? Center(
              child: Text(
                libraryProvider.isLoading ? 'Loading…' : 'No policies yet',
              ),
            )
          : ListView(
              children: [
                for (final policy in libraryProvider.policies)
                  ListTile(
                    title: Text(policy.name),
                    subtitle: Text(
                      '${libraryProvider.library(policy.libraryId)?.name ?? policy.libraryId} · '
                      '${policy.memberCategory}\n${policy.summary}',
                    ),
                    isThreeLine: true,
                    leading: policy.active ? null : const InactiveBadge(),
                    onTap: canEdit
                        ? () => PolicySheet.show(context, policy: policy)
                        : null,
                    trailing: canEdit
                        ? IconButton(
                            tooltip: policy.active ? 'Deactivate' : 'Activate',
                            icon: Icon(
                              policy.active
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_rounded,
                            ),
                            onPressed: () async {
                              if (!await libraryProvider.setPolicyActive(
                                    policy.id,
                                    active: !policy.active,
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
                  ),
              ],
            ),
    );
  }
}
