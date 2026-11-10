import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/policies/widgets/policies_table.dart';
import 'package:school_library/src/ui/policies/widgets/policy_card.dart';
import 'package:school_library/src/ui/policies/widgets/policy_dialog.dart';
import 'package:school_library/src/ui/policies/widgets/policy_empty_states.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_tab_bar.dart';

/// Borrowing policies per library and member category (FRS 11.8).
class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});

  Future<void> _toggle(
    BuildContext context,
    LibraryProvider libraryProvider,
    LibraryPolicy policy,
  ) async {
    if (!await libraryProvider.setPolicyActive(
          policy.id,
          active: !policy.active,
        ) &&
        context.mounted) {
      showMessage(context, libraryProvider.errorMessage ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final allPolicies = libraryProvider.policies;
    final isWide = context.isWide;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowing Policies'),
        actions: [
          IconButton(
            tooltip: 'Refresh policies',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadMasters(),
          ),
        ],
        bottom: const LibraryTabBar(
          tabs: librarySettingsTabs,
          activePath: LibraryRoutes.libraryPolicies,
        ),
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => PolicyDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Policy'),
            ),
      body: libraryProvider.isLoading && allPolicies.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : allPolicies.isEmpty
          ? PolicyInitialEmptyState(
              onAddDefault: () async {
                if (!await libraryProvider.seedDefaultPolicies() &&
                    context.mounted) {
                  showMessage(
                    context,
                    libraryProvider.errorMessage ?? 'Failed',
                  );
                }
              },
            )
          : isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: PoliciesTable(
                policies: allPolicies,
                onToggleActive: (policy) =>
                    _toggle(context, libraryProvider, policy),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => libraryProvider.loadMasters(),
              child: IcueAdaptiveCardList(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: allPolicies.length,
                itemBuilder: (context, index) {
                  final policy = allPolicies[index];
                  return PolicyCard(
                    policy: policy,
                    scope: libraryProvider.policyScope(policy),
                    libraryName:
                        libraryProvider.library(policy.libraryId)?.name ??
                        policy.libraryId,
                    onTap: () => PolicyDialog.show(context, policy: policy),
                    onToggleActive: () =>
                        _toggle(context, libraryProvider, policy),
                  );
                },
              ),
            ),
    );
  }
}
