import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/widgets/verification_create_sheet.dart';
import 'package:school_library/src/ui/widgets/verification_sheet.dart';

/// Library stock verification sessions (FRS 11.16).
class LibraryVerificationPage extends StatefulWidget {
  const LibraryVerificationPage({super.key});

  @override
  State<LibraryVerificationPage> createState() => _LibVerificationPageState();
}

class _LibVerificationPageState extends State<LibraryVerificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadVerifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Verification')),
      floatingActionButton:
          libraryProvider.access.can('library.catalogue.manage')
          ? FloatingActionButton.extended(
              onPressed: () => VerificationCreateSheet.show(context),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('New verification'),
            )
          : null,
      body: libraryProvider.verifications.isEmpty
          ? Center(
              child: Text(
                libraryProvider.verificationsLoading
                    ? 'Loading…'
                    : libraryProvider.errorMessage ?? 'No verifications yet',
              ),
            )
          : ListView.builder(
              itemCount:
                  libraryProvider.verifications.length +
                  (libraryProvider.hasMoreVerifications ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= libraryProvider.verifications.length) {
                  return Center(
                    child: TextButton(
                      onPressed: libraryProvider.verificationsLoading
                          ? null
                          : () => libraryProvider.loadVerifications(more: true),
                      child: const Text('Load more'),
                    ),
                  );
                }
                final verification = libraryProvider.verifications[i];
                return ListTile(
                  title: Text(
                    '${verification.number} · ${verification.libraryName}',
                  ),
                  subtitle: Text(
                    '${verification.shelf ?? 'All shelves'} · ${verification.verifiedDate ?? ''} · '
                    '${verification.scanned.length}/${verification.expected.length} scanned',
                  ),
                  trailing: Chip(
                    label: Text(verificationStatusLabel(verification.status)),
                  ),
                  onTap: () => VerificationSheet.show(context, verification.id),
                );
              },
            ),
    );
  }
}
