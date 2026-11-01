import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/verification_create_sheet.dart';
import 'package:icueadmin/features/library/widgets/verification_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Library stock verification sessions (FRS 11.16).
class LibVerificationPage extends StatefulWidget {
  const LibVerificationPage({super.key});

  @override
  State<LibVerificationPage> createState() => _LibVerificationPageState();
}

class _LibVerificationPageState extends State<LibVerificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadVerifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Verification')),
      floatingActionButton: p.access.can('lib.catalogue.manage')
          ? FloatingActionButton.extended(
              onPressed: () => VerificationCreateSheet.show(context),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('New verification'),
            )
          : null,
      body: p.verifications.isEmpty
          ? Center(
              child: Text(
                p.verificationsLoading
                    ? 'Loading…'
                    : p.errorMessage ?? 'No verifications yet',
              ),
            )
          : ListView.builder(
              itemCount:
                  p.verifications.length + (p.hasMoreVerifications ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= p.verifications.length) {
                  return Center(
                    child: TextButton(
                      onPressed: p.verificationsLoading
                          ? null
                          : () => p.loadVerifications(more: true),
                      child: const Text('Load more'),
                    ),
                  );
                }
                final v = p.verifications[i];
                return ListTile(
                  title: Text('${v.number} · ${v.libraryName}'),
                  subtitle: Text(
                    '${v.shelf ?? 'All shelves'} · ${v.verifiedOn ?? ''} · '
                    '${v.scanned.length}/${v.expected.length} scanned',
                  ),
                  trailing: Chip(
                    label: Text(verificationStatusLabel(v.status)),
                  ),
                  onTap: () => VerificationSheet.show(context, v.id),
                );
              },
            ),
    );
  }
}
