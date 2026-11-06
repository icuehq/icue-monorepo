import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/verification/widgets/verification_card.dart';
import 'package:school_library/src/ui/verification/widgets/verification_create_sheet.dart';
import 'package:school_library/src/ui/verification/widgets/verification_empty_states.dart';
import 'package:school_library/src/ui/verification/widgets/verification_sheet.dart';

/// Library stock verification sessions (FRS 11.16).
class LibraryVerificationPage extends StatefulWidget {
  const LibraryVerificationPage({super.key});

  @override
  State<LibraryVerificationPage> createState() =>
      _LibraryVerificationPageState();
}

class _LibraryVerificationPageState extends State<LibraryVerificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadVerifications(),
    );
  }

  Widget _statusPill(BuildContext context, String status) {
    final (color, background) = switch (status) {
      'approved' => (
        Colors.green.shade700,
        Colors.green.withValues(alpha: 0.12),
      ),
      'submitted' => (
        Colors.blue.shade700,
        Colors.blue.withValues(alpha: 0.12),
      ),
      _ => (Colors.orange.shade800, Colors.orange.withValues(alpha: 0.12)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        verificationStatusLabel(status),
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
    final canCreate = libraryProvider.access.can('library.catalogue');
    final allVerifications = libraryProvider.verifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh verifications',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadVerifications(),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => VerificationCreateSheet.show(context),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('New verification'),
            )
          : null,
      body: CenteredBody(
        child: libraryProvider.verificationsLoading && allVerifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : allVerifications.isEmpty
            ? VerificationInitialEmptyState(
                onCreate: canCreate
                    ? () => VerificationCreateSheet.show(context)
                    : null,
              )
            : RefreshIndicator(
                onRefresh: () => libraryProvider.loadVerifications(),
                child: AdaptiveList<LibraryVerification>(
                  items: allVerifications,
                  onTap: (verification) =>
                      VerificationSheet.show(context, verification.id),
                  columns: [
                    AdaptiveColumn(
                      label: 'Session #',
                      flex: 2,
                      cell: (context, verification) => Text(
                        verification.number,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    AdaptiveColumn.text(
                      'Library',
                      (verification) => verification.libraryName,
                      flex: 2,
                    ),
                    AdaptiveColumn.text(
                      'Shelf',
                      (verification) => verification.shelf ?? 'All shelves',
                    ),
                    AdaptiveColumn(
                      label: 'Scanned / Expected',
                      flex: 2,
                      cell: (context, verification) {
                        final totalExpected = verification.expected.length;
                        final totalScanned = verification.scanned.length;
                        return Text('$totalScanned / $totalExpected');
                      },
                    ),
                    AdaptiveColumn(
                      label: 'Missing',
                      cell: (context, verification) => Text(
                        '${verification.missing.length}',
                        style: TextStyle(
                          color: verification.missing.isNotEmpty
                              ? Theme.of(context).colorScheme.error
                              : null,
                          fontWeight: verification.missing.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    AdaptiveColumn.text(
                      'Date',
                      (verification) =>
                          verification.verifiedDate?.toDisplayDay() ?? '—',
                    ),
                    AdaptiveColumn(
                      label: 'Status',
                      cell: (context, verification) =>
                          _statusPill(context, verification.status),
                    ),
                  ],
                  cardBuilder: (context, verification) => VerificationCard(
                    verification: verification,
                    onTap: () =>
                        VerificationSheet.show(context, verification.id),
                  ),
                  footer: libraryProvider.hasMoreVerifications
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextButton(
                              onPressed: libraryProvider.verificationsLoading
                                  ? null
                                  : () => libraryProvider.loadVerifications(
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
    );
  }
}
