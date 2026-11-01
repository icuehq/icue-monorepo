import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/transfer_request_sheet.dart';
import 'package:icueadmin/features/library/widgets/transfer_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Inter-library transfers (FRS 11.15).
class LibTransfersPage extends StatefulWidget {
  const LibTransfersPage({super.key});

  @override
  State<LibTransfersPage> createState() => _LibTransfersPageState();
}

class _LibTransfersPageState extends State<LibTransfersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadTransfers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    String lib(String id) => p.libraries
        .firstWhere(
          (l) => l.id == id,
          orElse: () => LibLibrary(
            id: id,
            code: '',
            name: id,
            campusId: 0,
            staffIds: const [],
            active: true,
          ),
        )
        .name;

    return Scaffold(
      appBar: AppBar(title: const Text('Library Transfers')),
      floatingActionButton: p.access.can('lib.catalogue.manage')
          ? FloatingActionButton.extended(
              onPressed: () => TransferRequestSheet.show(context),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('New transfer'),
            )
          : null,
      body: p.transfers.isEmpty
          ? Center(
              child: Text(
                p.transfersLoading
                    ? 'Loading…'
                    : p.errorMessage ?? 'No transfers yet',
              ),
            )
          : ListView.builder(
              itemCount: p.transfers.length + (p.hasMoreTransfers ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= p.transfers.length) {
                  return Center(
                    child: TextButton(
                      onPressed: p.transfersLoading
                          ? null
                          : () => p.loadTransfers(more: true),
                      child: const Text('Load more'),
                    ),
                  );
                }
                final t = p.transfers[i];
                return ListTile(
                  title: Text(t.number),
                  subtitle: Text(
                    '${lib(t.fromLibraryId)} → ${lib(t.toLibraryId)} · '
                    '${t.lines.length} copies',
                  ),
                  trailing: Chip(label: Text(transferStatusLabel(t.status))),
                  onTap: () => TransferSheet.show(context, t),
                );
              },
            ),
    );
  }
}
