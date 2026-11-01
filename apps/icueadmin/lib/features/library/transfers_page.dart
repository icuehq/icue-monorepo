import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/transfer_request_sheet.dart';
import 'package:icueadmin/features/library/widgets/transfer_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Inter-library transfers (FRS 11.15).
class LibraryTransfersPage extends StatefulWidget {
  const LibraryTransfersPage({super.key});

  @override
  State<LibraryTransfersPage> createState() => _LibTransfersPageState();
}

class _LibTransfersPageState extends State<LibraryTransfersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadTransfers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    String lib(String id) => libraryProvider.libraries
        .firstWhere(
          (schoolLibrary) => schoolLibrary.id == id,
          orElse: () => SchoolLibrary(
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
      floatingActionButton:
          libraryProvider.access.can('library.catalogue.manage')
          ? FloatingActionButton.extended(
              onPressed: () => TransferRequestSheet.show(context),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('New transfer'),
            )
          : null,
      body: libraryProvider.transfers.isEmpty
          ? Center(
              child: Text(
                libraryProvider.transfersLoading
                    ? 'Loading…'
                    : libraryProvider.errorMessage ?? 'No transfers yet',
              ),
            )
          : ListView.builder(
              itemCount:
                  libraryProvider.transfers.length +
                  (libraryProvider.hasMoreTransfers ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= libraryProvider.transfers.length) {
                  return Center(
                    child: TextButton(
                      onPressed: libraryProvider.transfersLoading
                          ? null
                          : () => libraryProvider.loadTransfers(more: true),
                      child: const Text('Load more'),
                    ),
                  );
                }
                final transfer = libraryProvider.transfers[i];
                return ListTile(
                  title: Text(transfer.number),
                  subtitle: Text(
                    '${lib(transfer.fromLibraryId)} → ${lib(transfer.toLibraryId)} · '
                    '${transfer.lineItems.length} copies',
                  ),
                  trailing: Chip(
                    label: Text(transferStatusLabel(transfer.status)),
                  ),
                  onTap: () => TransferSheet.show(context, transfer),
                );
              },
            ),
    );
  }
}
