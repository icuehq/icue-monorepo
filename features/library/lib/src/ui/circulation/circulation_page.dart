import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart' show textSearchSupported;
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/circulation_empty_states.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_card.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_dialog.dart';
import 'package:school_library/src/ui/circulation/widgets/loans_table.dart';

/// Active loans (tap one to return or renew) and an Issue button that opens the step-by-step issue flow (FRS 11.9–11.11).
/// Every filter is a Firestore query, paged by the provider's `loans` pager.
class CirculationPage extends StatefulWidget {
  const CirculationPage({super.key});

  @override
  State<CirculationPage> createState() => _CirculationPageState();
}

class _CirculationPageState extends State<CirculationPage> {
  late final _searchController = TextEditingController(
    text: context.read<LibraryProvider>().loanSearch,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final libraryProvider = context.read<LibraryProvider>();
      unawaited(libraryProvider.loadStandards());
      libraryProvider.loadLoans();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    context.read<LibraryProvider>()
      ..loanSearch = value.trim()
      ..loadLoans();
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<LibraryProvider>().clearLoanFilters();
  }

  Future<void> _open(LibraryLoan loan) async {
    final book = await context.read<LibraryProvider>().book(loan.catalogueId);
    if (!mounted) return;
    await LoanDialog.show(context, loan, book?.title ?? loan.barcode);
  }

  Widget _filterBar(BuildContext context, LibraryProvider libraryProvider) {
    final theme = Theme.of(context);
    final total = libraryProvider.loans.total;
    Widget chip(String label, LoanDueFilter? due) {
      final selected = libraryProvider.loanDue == due;
      return ChoiceChip(
        label: Text(selected && total != null ? '$label ($total)' : label),
        selected: selected,
        onSelected: (_) => libraryProvider
          ..loanDue = due
          ..loadLoans(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip('All', null),
                  for (final due in LoanDueFilter.values) ...[
                    const SizedBox(width: 8),
                    chip(due.label, due),
                  ],
                ],
              ),
            ),
          ),
          if (textSearchSupported) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Title, member or adm. no.',
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
                  suffixIcon: libraryProvider.loanSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        )
                      : null,
                ),
                onSubmitted: _search,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final pager = libraryProvider.loans;
    final loans = pager.items;
    final today = todayIST();
    final isWide = context.isWide;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Books'),
        actions: [
          if (!isWide)
            IcueButton(
              label: 'Issue',
              onPressed: () => context.push(LibraryRoutes.libraryIssue),
              leadingIcon: Icons.add_rounded,
            ),
        ],
      ),
      body: isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: LoansTable(today: today, onOpen: _open),
            )
          : Column(
              children: [
                _filterBar(context, libraryProvider),
                const SizedBox(height: 6),
                Expanded(
                  child: pager.loading && loans.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : loans.isEmpty
                      ? (libraryProvider.loansFiltered
                            ? CirculationNoResultsState(
                                searchQuery: libraryProvider.loanSearch,
                                onClear: _clearFilters,
                              )
                            : const CirculationInitialEmptyState())
                      : RefreshIndicator(
                          onRefresh: libraryProvider.loadLoans,
                          child: IcueAdaptiveCardList(
                            itemCount: loans.length,
                            footer: IcueLoadMoreFooter.of(pager),
                            itemBuilder: (context, index) => LoanCard(
                              loan: loans[index],
                              today: today,
                              onTap: () => _open(loans[index]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
