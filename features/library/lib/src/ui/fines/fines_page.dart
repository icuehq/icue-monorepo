import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/fines/widgets/fine_card.dart';
import 'package:school_library/src/ui/fines/widgets/fine_dialog.dart';
import 'package:school_library/src/ui/fines/widgets/fine_empty_states.dart';
import 'package:school_library/src/ui/fines/widgets/fines_table.dart';

/// Manage overdue fines, damage penalties, and lost book charges (FRS 11.13).
class FinesPage extends StatefulWidget {
  const FinesPage({super.key});

  @override
  State<FinesPage> createState() => _FinesPageState();
}

class _FinesPageState extends State<FinesPage> {
  late final _searchController = TextEditingController(
    text: context.read<LibraryProvider>().fineSearch,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadFines(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String value) {
    context.read<LibraryProvider>()
      ..fineStatus = value == 'all' ? null : value
      ..loadFines();
  }

  void _search(String value) {
    context.read<LibraryProvider>()
      ..fineSearch = value.trim()
      ..loadFines();
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<LibraryProvider>().clearFineFilters();
  }

  Future<void> _open(LibraryFine fine) async {
    await FineDialog.show(context, fine);
    if (mounted) {
      await context.read<LibraryProvider>().loadFines();
    }
  }

  Widget _summaryBar(BuildContext context) {
    final theme = Theme.of(context);
    final totals = context.watch<LibraryProvider>().fineTotals;

    Widget metricItem(String label, String value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          metricItem(
            'Outstanding',
            totals?.outstanding.toRupees() ?? '…',
            theme.colorScheme.error,
            Icons.pending_actions_rounded,
          ),
          const SizedBox(width: 10),
          metricItem(
            'Collected',
            totals?.paid.toRupees() ?? '…',
            Colors.green.shade700,
            Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          metricItem(
            'Waived',
            totals?.waived.toRupees() ?? '…',
            Colors.blueGrey.shade700,
            Icons.handshake_outlined,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final pager = libraryProvider.fines;
    final status = libraryProvider.fineStatus ?? 'all';
    return Scaffold(
      appBar: AppBar(title: const Text('Fines')),
      body: context.isWide
          ? Column(
              children: [
                _summaryBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [Expanded(child: FinesTable(onOpen: _open))],
                    ),
                  ),
                ),
              ],
            )
          : IcueCenteredBody(
              child: Column(
                children: [
                  _summaryBar(context),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'all', label: Text('All')),
                                ButtonSegment(
                                  value: 'outstanding',
                                  label: Text('Outstanding'),
                                ),
                                ButtonSegment(
                                  value: 'partially_paid',
                                  label: Text('Partially paid'),
                                ),
                                ButtonSegment(
                                  value: 'paid',
                                  label: Text('Paid'),
                                ),
                                ButtonSegment(
                                  value: 'waived',
                                  label: Text('Waived'),
                                ),
                              ],
                              selected: {status},
                              onSelectionChanged: (values) =>
                                  _onStatusChanged(values.first),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Fine # or accession no.',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              suffixIcon: libraryProvider.fineSearch.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        _search('');
                                      },
                                    )
                                  : null,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _search,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: pager.loading && pager.items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : pager.items.isEmpty
                        ? (libraryProvider.fineSearch.isNotEmpty ||
                                  libraryProvider.fineType != null
                              ? FineNoResultsState(
                                  searchQuery: libraryProvider.fineSearch,
                                  onClear: _clearFilters,
                                )
                              : FineInitialEmptyState(status: status))
                        : RefreshIndicator(
                            onRefresh: libraryProvider.loadFines,
                            child: IcueAdaptiveCardList(
                              itemCount: pager.items.length,
                              footer: IcueLoadMoreFooter.of(pager),
                              itemBuilder: (context, index) => FineCard(
                                fine: pager.items[index],
                                onTap: () => _open(pager.items[index]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
