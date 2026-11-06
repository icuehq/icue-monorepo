import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/transfers/widgets/transfer_card.dart';
import 'package:school_library/src/ui/transfers/widgets/transfer_widgets.dart';

/// Inter-library transfers (FRS 11.15).
class LibraryTransfersPage extends StatefulWidget {
  const LibraryTransfersPage({super.key});

  @override
  State<LibraryTransfersPage> createState() => _LibraryTransfersPageState();
}

class _LibraryTransfersPageState extends State<LibraryTransfersPage> {
  static const _statuses = <(String?, String)>[
    (null, 'All'),
    ('requested', 'Requested'),
    ('approved', 'Approved'),
    ('dispatched', 'In transit'),
    ('partially_received', 'Partly received'),
    ('received', 'Received'),
    ('cancelled', 'Cancelled'),
  ];

  String? _status;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final libraryProvider = context.read<LibraryProvider>();
    if (libraryProvider.libraries.isEmpty) await libraryProvider.loadMasters();
    await libraryProvider.loadTransfers();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  Widget _statusPill(String status) {
    final color = transferStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        transferStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final access = libraryProvider.access;
    final theme = Theme.of(context);
    final transfers = [
      for (final transfer in libraryProvider.transfers)
        if (_status == null || transfer.status == _status) transfer,
    ];
    final loading = !_loaded || libraryProvider.transfersLoading;
    final failure = libraryProvider.errorMessage;

    String name(String id) => libraryProvider.library(id)?.name ?? id;

    Widget empty() => Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              failure != null
                  ? 'Could not load transfers'
                  : _status == null
                  ? 'No transfers yet'
                  : 'No ${transferStatusLabel(_status!).toLowerCase()} transfers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              failure ?? 'Move copies between libraries. Each transfer is requested, approved, dispatched, and then received.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (failure != null)
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              )
            else if (_status != null)
              OutlinedButton(
                onPressed: () => setState(() => _status = null),
                child: const Text('Show all transfers'),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Transfers'),
        actions: [
          IconButton(
            tooltip: 'Refresh transfers',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: access.can('library.catalogue')
          ? FloatingActionButton.extended(
              onPressed: () => _open(LibraryRoutes.libraryTransferForm),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('New transfer'),
            )
          : null,
      body: CenteredBody(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  for (final (key, label) in _statuses)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(label),
                        selected: _status == key,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _status = key),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: !_loaded || (loading && transfers.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : transfers.isEmpty
                    ? empty()
                    : AdaptiveList<LibraryTransfer>(
                        items: transfers,
                        onTap: (transfer) => _open(
                          '${LibraryRoutes.libraryTransferDetail}?id=${transfer.id}',
                        ),
                        columns: [
                          AdaptiveColumn(
                            label: 'Transfer #',
                            flex: 2,
                            cell: (context, transfer) => Text(
                              transfer.number,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AdaptiveColumn.text(
                            'From',
                            (transfer) => name(transfer.fromLibraryId),
                            flex: 2,
                          ),
                          AdaptiveColumn.text(
                            'To',
                            (transfer) => name(transfer.toLibraryId),
                            flex: 2,
                          ),
                          AdaptiveColumn(
                            label: 'Copies',
                            cell: (context, transfer) {
                              final total = transfer.lineItems.length;
                              final received = total - transfer.pending.length;
                              return Text(
                                received == total
                                    ? '$total copies'
                                    : '$received/$total received',
                              );
                            },
                          ),
                          AdaptiveColumn.text(
                            'Date',
                            (transfer) => transfer.requestedDate.toDisplayDay(),
                          ),
                          AdaptiveColumn(
                            label: 'Status',
                            cell: (context, transfer) =>
                                _statusPill(transfer.status),
                          ),
                          AdaptiveColumn(
                            label: 'Action',
                            flex: 2,
                            cell: (context, transfer) {
                              final action = transferNextAction(
                                transfer,
                                access,
                              );
                              if (action == null) return const Text('—');
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  action,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        cardBuilder: (context, transfer) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TransferCard(
                            transfer: transfer,
                            fromName: name(transfer.fromLibraryId),
                            toName: name(transfer.toLibraryId),
                            nextAction: transferNextAction(transfer, access),
                            onTap: () => _open(
                              '${LibraryRoutes.libraryTransferDetail}?id=${transfer.id}',
                            ),
                          ),
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
