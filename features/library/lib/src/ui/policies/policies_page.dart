import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/policies/widgets/policy_card.dart';
import 'package:school_library/src/ui/policies/widgets/policy_empty_states.dart';
import 'package:school_library/src/ui/policies/widgets/policy_sheet.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_tab_bar.dart';

/// Borrowing policies per library and member category (FRS 11.8).
class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});

  Widget _activeToggle(
    BuildContext context,
    LibraryProvider libraryProvider,
    LibraryPolicy policy,
  ) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: policy.active ? 'Deactivate policy' : 'Activate policy',
      icon: Icon(
        policy.active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
        color: policy.active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: 28,
      ),
      onPressed: () async {
        if (!await libraryProvider.setPolicyActive(
              policy.id,
              active: !policy.active,
            ) &&
            context.mounted) {
          showMessage(context, libraryProvider.errorMessage ?? 'Failed');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.settings');
    final allPolicies = libraryProvider.policies;

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
          tabs: libraryMemberTabs,
          activePath: LibraryRoutes.libraryPolicies,
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => PolicySheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Policy'),
            )
          : null,
      body: CenteredBody(
        child: libraryProvider.isLoading && allPolicies.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : allPolicies.isEmpty
            ? PolicyInitialEmptyState(
                onCreate: canEdit ? () => PolicySheet.show(context) : null,
              )
            : RefreshIndicator(
                onRefresh: () => libraryProvider.loadMasters(),
                child: AdaptiveList<LibraryPolicy>(
                  items: allPolicies,
                  onTap: canEdit
                      ? (policy) => PolicySheet.show(context, policy: policy)
                      : null,
                  columns: [
                    AdaptiveColumn(
                      label: 'Policy',
                      flex: 2,
                      cell: (context, policy) => Row(
                        children: [
                          if (!policy.active) ...[
                            const InactiveBadge(),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              policy.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AdaptiveColumn.text(
                      'Library',
                      (policy) =>
                          libraryProvider.library(policy.libraryId)?.name ??
                          policy.libraryId,
                    ),
                    AdaptiveColumn.text(
                      'Applies to',
                      (policy) => policy.appliesTo,
                    ),
                    AdaptiveColumn.text(
                      'Rules Summary',
                      (policy) => policy.summary,
                      flex: 3,
                    ),
                    AdaptiveColumn(
                      label: 'Status',
                      cell: (context, policy) => canEdit
                          ? _activeToggle(context, libraryProvider, policy)
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: policy.active
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                policy.active ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: policy.active
                                      ? Colors.green.shade700
                                      : null,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ],
                  cardBuilder: (context, policy) => PolicyCard(
                    policy: policy,
                    libraryName:
                        libraryProvider.library(policy.libraryId)?.name ??
                        policy.libraryId,
                    canEdit: canEdit,
                    onTap: () => PolicySheet.show(context, policy: policy),
                    onToggleActive: () async {
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
                  ),
                ),
              ),
      ),
    );
  }
}
