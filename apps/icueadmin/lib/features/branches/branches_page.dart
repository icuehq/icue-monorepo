import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/branches/widgets/branch_card.dart';
import 'package:icueadmin/features/branches/widgets/branch_search_bar.dart';
import 'package:icueadmin/features/branches/widgets/branches_app_bar.dart';
import 'package:icueadmin/features/branches/widgets/branches_empty_state.dart';
import 'package:icueadmin/features/branches/widgets/branches_header.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});

  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectingBranchId;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().getBranchesByZoneId();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _handleSelectBranch(AuthProvider provider, Branch branch) async {
    if (_selectingBranchId != null) return;

    setState(() {
      _selectingBranchId = branch.id;
    });

    try {
      await provider.selectZonalBranch(branch);
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to select branch: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to select ${branch.schoolName}. Please try again.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingBranchId = null;
        });
      }
    }
  }

  List<Branch> _filterBranches(List<Branch> branches) {
    if (_searchQuery.isEmpty) return branches;

    return branches.where((branch) {
      final matchesName = branch.schoolName.toLowerCase().contains(
        _searchQuery,
      );
      final matchesShort = branch.schoolShortName.toLowerCase().contains(
        _searchQuery,
      );
      return matchesName || matchesShort;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AuthProvider>();
    final allBranches = provider.branches;
    final filteredBranches = _filterBranches(allBranches);
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: BranchesAppBar(
        onLogout: () async {
          await provider.logout();
        },
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: provider.loading && allBranches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading available branches...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.getBranchesByZoneId(),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BranchesHeader(
                                    user: provider.user,
                                    totalCount: allBranches.length,
                                    filteredCount: filteredBranches.length,
                                    isSearching: isSearching,
                                  ),
                                  if (allBranches.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    BranchSearchBar(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      onClear: _clearSearch,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (allBranches.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: BranchesEmptyState(
                                isFiltered: false,
                                onAction: () => provider.getBranchesByZoneId(),
                              ),
                            )
                          else if (filteredBranches.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: BranchesEmptyState(
                                isFiltered: true,
                                searchQuery: _searchController.text,
                                onAction: _clearSearch,
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              sliver: SliverList.separated(
                                itemCount: filteredBranches.length,
                                itemBuilder: (context, index) {
                                  final branch = filteredBranches[index];
                                  final isSelecting =
                                      _selectingBranchId == branch.id;
                                  final isSelected =
                                      provider.selectedBranch?.id == branch.id;

                                  return BranchCard(
                                    branch: branch,
                                    isSelecting: isSelecting,
                                    isSelected: isSelected,
                                    onTap: () =>
                                        _handleSelectBranch(provider, branch),
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
