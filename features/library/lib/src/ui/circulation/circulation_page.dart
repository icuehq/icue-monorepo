import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/circulation_empty_states.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_card.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_sheet.dart';
import 'package:school_library/src/ui/shared/person_picker.dart';

enum CirculationFilter { all, overdue, dueToday }

/// Issue, return and renew (FRS 11.9–11.11): scan a copy to issue it to the typed member, or to take it back.
class CirculationPage extends StatefulWidget {
  const CirculationPage({super.key});

  @override
  State<CirculationPage> createState() => _CirculationPageState();
}

class _CirculationPageState extends State<CirculationPage> {
  final _searchController = TextEditingController();
  LibraryPerson? _person;
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

  Future<void> _issue(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final person = _person;
    if (person == null) {
      return showMessage(context, 'Choose the student or teacher first');
    }
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    if (copy == null) return showMessage(context, 'No copy found for "$code"');
    final success = await libraryProvider.issueLoan({
      'person': person.toPayload(),
      'copyId': copy.id,
    });
    if (!mounted) return;
    showMessage(
      context,
      success
          ? '${copy.accessionNumber} issued to ${person.name}'
          : libraryProvider.errorMessage ?? 'Failed',
    );
  }

  Future<void> _find(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    if (copy == null) return showMessage(context, 'No copy found for "$code"');
    final loan = await libraryProvider.activeLoanOf(copy.id);
    if (!mounted) return;
    if (loan == null) {
      return showMessage(context, '${copy.accessionNumber} is not on loan');
    }
    await _open(loan);
  }

  Future<void> _open(LibraryLoan loan) async {
    final book = await context.read<LibraryProvider>().book(loan.catalogueId);
    if (!mounted) return;
    await LoanSheet.show(context, loan, book?.title ?? loan.accessionNumber);
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

  Widget _deskCard(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.isWide;
    final memberPicker = PersonPicker(onChanged: (person) => _person = person);
    final issueScanner = ScanField(
      hint: 'Scan copy barcode to ISSUE',
      onScan: _issue,
      clearOnScan: true,
    );
    final returnScanner = ScanField(
      hint: 'Scan copy barcode to RETURN / RENEW',
      onScan: _find,
      clearOnScan: true,
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.point_of_sale_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Circulation Desk',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Issue, return, or renew instantly',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: memberPicker),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: issueScanner),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: returnScanner),
                ],
              )
            else ...[
              memberPicker,
              const SizedBox(height: 10),
              issueScanner,
              const SizedBox(height: 10),
              returnScanner,
            ],
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<CirculationFilter>(
                segments: [
                  ButtonSegment(
                    value: CirculationFilter.all,
                    label: Text('All ($totalCount)'),
                  ),
                  ButtonSegment(
                    value: CirculationFilter.overdue,
                    label: Text('Overdue ($overdueCount)'),
                  ),
                  ButtonSegment(
                    value: CirculationFilter.dueToday,
                    label: Text('Due Today ($dueTodayCount)'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selected) {
                  setState(() => _filter = selected.first);
                },
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
        final matchAccession = loan.accessionNumber.toLowerCase().contains(
          query,
        );
        final matchNumber = loan.number.toLowerCase().contains(query);
        return matchMember || matchAccession || matchNumber;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Circulation'),
        actions: [
          IconButton(
            tooltip: 'Refresh loans',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadLoans(),
          ),
        ],
      ),
      body: CenteredBody(
        child: Column(
          children: [
            _deskCard(context),
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
                                  loan.accessionNumber,
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
