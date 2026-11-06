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

  /// False until the first fetch ends, so an earlier visit's rows never flash.
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final libraryProvider = context.read<LibraryProvider>();
    // Access (campuses) and library names must be known before transfers are read.
    if (libraryProvider.libraries.isEmpty) await libraryProvider.loadMasters();
    await libraryProvider.loadTransfers();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
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
            Icon(
              Icons.swap_horiz_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              failure != null
                  ? 'Could not load transfers'
                  : _status == null
                  ? 'No transfers yet'
                  : 'No ${transferStatusLabel(_status!).toLowerCase()} transfers',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              failure ?? 'Move copies between libraries. Each transfer is requested, approved, dispatched and then received.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
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
      appBar: AppBar(title: const Text('Library Transfers')),
      floatingActionButton: access.can('library.catalogue')
          ? FloatingActionButton.extended(
              onPressed: () => _open(LibraryRoutes.libraryTransferForm),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('New transfer'),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = transfers[index];
                        return TransferCard(
                          transfer: transfer,
                          fromName: name(transfer.fromLibraryId),
                          toName: name(transfer.toLibraryId),
                          nextAction: transferNextAction(transfer, access),
                          onTap: () => _open(
                            '${LibraryRoutes.libraryTransferDetail}?id=${transfer.id}',
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
