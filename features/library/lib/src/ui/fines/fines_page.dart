import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/fines/widgets/fine_card.dart';
import 'package:school_library/src/ui/fines/widgets/fine_empty_states.dart';
import 'package:school_library/src/ui/fines/widgets/fine_sheet.dart';

/// Manage overdue fines, damage penalties, and lost book charges (FRS 11.13).
class FinesPage extends StatefulWidget {
  const FinesPage({super.key});

  @override
  State<FinesPage> createState() => _FinesPageState();
}

class _FinesPageState extends State<FinesPage> {
  final _searchController = TextEditingController();
  String _status = 'outstanding';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadFines(status: _status),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String value) {
    setState(() => _status = value);
    context.read<LibraryProvider>().loadFines(status: value);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _open(LibraryFine fine) async {
    await FineSheet.show(context, fine);
    if (mounted) {
      await context.read<LibraryProvider>().loadFines(status: _status);
    }
  }

  Widget _statusPill(BuildContext context, LibraryFine fine) {
    final theme = Theme.of(context);
    final (color, background) = switch (fine.status) {
      'paid' => (Colors.green.shade700, Colors.green.withValues(alpha: 0.12)),
      'partially_paid' => (
        Colors.orange.shade800,
        Colors.orange.withValues(alpha: 0.12),
      ),
      'waived' => (
        Colors.blueGrey.shade700,
        Colors.blueGrey.withValues(alpha: 0.12),
      ),
      _ => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        humanizeStatus(fine.status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _typePill(BuildContext context, String type) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        fineTypeLabel(type),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _summaryBar(BuildContext context, List<LibraryFine> fines) {
    final theme = Theme.of(context);
    double totalOutstanding = 0;
    double totalPaid = 0;
    double totalWaived = 0;

    for (final fine in fines) {
      totalOutstanding += fine.outstanding;
      totalPaid += fine.paid;
      totalWaived += fine.waived;
    }

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
            totalOutstanding.toRupees(),
            theme.colorScheme.error,
            Icons.pending_actions_rounded,
          ),
          const SizedBox(width: 10),
          metricItem(
            'Collected',
            totalPaid.toRupees(),
            Colors.green.shade700,
            Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          metricItem(
            'Waived',
            totalWaived.toRupees(),
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
    final allFines = libraryProvider.fines;

    final filteredFines = allFines.where((fine) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchMember = fine.memberLabel.toLowerCase().contains(query);
        final matchFineNumber = fine.fineNumber.toLowerCase().contains(query);
        final matchAccession =
            fine.accessionNumber?.toLowerCase().contains(query) ?? false;
        return matchMember || matchFineNumber || matchAccession;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fines & Penalties'),
        actions: [
          IconButton(
            tooltip: 'Refresh fines',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadFines(status: _status),
          ),
        ],
      ),
      body: CenteredBody(
        child: Column(
          children: [
            _summaryBar(context, allFines),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'outstanding',
                            label: Text('Outstanding'),
                          ),
                          ButtonSegment(
                            value: 'partially_paid',
                            label: Text('Partially paid'),
                          ),
                          ButtonSegment(value: 'paid', label: Text('Paid')),
                          ButtonSegment(value: 'waived', label: Text('Waived')),
                          ButtonSegment(value: 'all', label: Text('All')),
                        ],
                        selected: {_status},
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
                        hintText: 'Search member, fine #…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
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
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: libraryProvider.finesLoading && allFines.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFines.isEmpty
                  ? (allFines.isEmpty
                        ? FineInitialEmptyState(status: _status)
                        : FineNoResultsState(
                            searchQuery: _searchQuery,
                            onClear: _clearSearch,
                          ))
                  : RefreshIndicator(
                      onRefresh: () =>
                          libraryProvider.loadFines(status: _status),
                      child: AdaptiveList<LibraryFine>(
                        items: filteredFines,
                        onTap: _open,
                        columns: [
                          AdaptiveColumn(
                            label: 'Fine #',
                            flex: 2,
                            cell: (context, fine) => Text(
                              fine.fineNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AdaptiveColumn(
                            label: 'Member',
                            flex: 3,
                            cell: (context, fine) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  fine.memberType == 'teacher'
                                      ? Icons.person_outline_rounded
                                      : Icons.school_outlined,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    fine.memberLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdaptiveColumn(
                            label: 'Type',
                            flex: 2,
                            cell: (context, fine) =>
                                _typePill(context, fine.type),
                          ),
                          AdaptiveColumn.text(
                            'Total',
                            (fine) => fine.amount.toRupees(),
                          ),
                          AdaptiveColumn.text(
                            'Paid',
                            (fine) => fine.paid.toRupees(),
                          ),
                          AdaptiveColumn(
                            label: 'Due',
                            cell: (context, fine) => Text(
                              fine.outstanding.toRupees(),
                              style: TextStyle(
                                color: fine.outstanding > 0
                                    ? theme.colorScheme.error
                                    : null,
                                fontWeight: fine.outstanding > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          AdaptiveColumn(
                            label: 'Status',
                            cell: (context, fine) => _statusPill(context, fine),
                          ),
                        ],
                        cardBuilder: (context, fine) =>
                            FineCard(fine: fine, onTap: () => _open(fine)),
                        footer: libraryProvider.hasMoreFines
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: TextButton(
                                    onPressed: libraryProvider.finesLoading
                                        ? null
                                        : () => libraryProvider.loadFines(
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
