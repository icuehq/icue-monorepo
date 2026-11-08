import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/circulation_empty_states.dart';
import 'package:school_library/src/ui/circulation/widgets/circulation_tabs.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_flow.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_card.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_dialog.dart';

enum CirculationFilter { all, overdue, dueToday }

/// Active loans (tap one to return or renew) and an Issue button that opens the step-by-step issue flow (FRS 11.9–11.11).
class CirculationPage extends StatefulWidget {
  const CirculationPage({super.key});

  @override
  State<CirculationPage> createState() => _CirculationPageState();
}

class _CirculationPageState extends State<CirculationPage> {
  final _searchController = TextEditingController();
  var _filter = CirculationFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadLoans(),
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

  Future<void> _open(LibraryLoan loan) async {
    final book = await context.read<LibraryProvider>().book(loan.catalogueId);
    if (!mounted) return;
    await LoanDialog.show(context, loan, book?.title ?? loan.barcode);
  }

  Widget _statusPill(BuildContext context, LibraryLoan loan, String today) {
    final theme = Theme.of(context);
    final daysLate = loan.overdueOn(today);
    final isLate = daysLate > 0;
    final color = isLate ? theme.colorScheme.error : theme.colorScheme.primary;
    final background = isLate
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isLate ? '$daysLate d late' : 'On time',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _filterBar(
    BuildContext context, {
    required int totalCount,
    required int overdueCount,
    required int dueTodayCount,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All ($totalCount)'),
                    selected: _filter == CirculationFilter.all,
                    onSelected: (_) =>
                        setState(() => _filter = CirculationFilter.all),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Overdue ($overdueCount)'),
                    selected: _filter == CirculationFilter.overdue,
                    onSelected: (_) =>
                        setState(() => _filter = CirculationFilter.overdue),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Due Today ($dueTodayCount)'),
                    selected: _filter == CirculationFilter.dueToday,
                    onSelected: (_) =>
                        setState(() => _filter = CirculationFilter.dueToday),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search loans…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
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
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final today = todayIST();
    final allLoans = libraryProvider.loans;

    final overdueCount = allLoans
        .where((loan) => loan.overdueOn(today) > 0)
        .length;
    final dueTodayCount = allLoans
        .where((loan) => loan.dueDate == today)
        .length;

    final filteredLoans = allLoans.where((loan) {
      if (_filter == CirculationFilter.overdue && loan.overdueOn(today) <= 0) {
        return false;
      }
      if (_filter == CirculationFilter.dueToday && loan.dueDate != today) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchMember = loan.memberLabel.toLowerCase().contains(query);
        final matchAccession = loan.barcode.toLowerCase().contains(query);
        final matchNumber = loan.number.toLowerCase().contains(query);
        return matchMember || matchAccession || matchNumber;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Circulation'),
        actions: [
          FilledButton.icon(
            onPressed: () => IssueFlow.show(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Issue'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          ),
          IconButton(
            tooltip: 'Refresh loans',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadLoans(),
          ),
        ],
        bottom: CirculationTabBar(activeTab: CirculationTab.loans),
      ),
      body: CenteredBody(
        child: Column(
          children: [
            _filterBar(
              context,
              totalCount: allLoans.length,
              overdueCount: overdueCount,
              dueTodayCount: dueTodayCount,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: libraryProvider.loansLoading && allLoans.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredLoans.isEmpty
                  ? (allLoans.isEmpty
                        ? const CirculationInitialEmptyState()
                        : CirculationNoResultsState(
                            searchQuery: _searchQuery,
                            onClear: _clearSearch,
                          ))
                  : RefreshIndicator(
                      onRefresh: () => libraryProvider.loadLoans(),
                      child: AdaptiveList<LibraryLoan>(
                        items: filteredLoans,
                        onTap: _open,
                        columns: [
                          AdaptiveColumn(
                            label: 'Copy',
                            flex: 2,
                            cell: (context, loan) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  loan.barcode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdaptiveColumn(
                            label: 'Member',
                            flex: 3,
                            cell: (context, loan) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  loan.memberType == 'teacher'
                                      ? Icons.person_outline_rounded
                                      : Icons.school_outlined,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    loan.memberLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdaptiveColumn.text('Loan #', (loan) => loan.number),
                          AdaptiveColumn.text(
                            'Issued',
                            (loan) => loan.issuedDate.toDisplayDay(),
                          ),
                          AdaptiveColumn.text(
                            'Due',
                            (loan) => loan.dueDate.toDisplayDay(),
                          ),
                          AdaptiveColumn(
                            label: 'Status',
                            cell: (context, loan) =>
                                _statusPill(context, loan, today),
                          ),
                        ],
                        cardBuilder: (context, loan) => LoanCard(
                          loan: loan,
                          today: today,
                          onTap: () => _open(loan),
                        ),
                        footer: libraryProvider.hasMoreLoans
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: TextButton(
                                    onPressed: libraryProvider.loansLoading
                                        ? null
                                        : () => libraryProvider.loadLoans(
                                            more: true,
                                          ),
                                    child: const Text('Load more'),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
