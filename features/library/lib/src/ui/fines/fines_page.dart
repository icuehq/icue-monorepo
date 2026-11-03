import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/fines/widgets/fine_sheet.dart';

/// Manage overdue fines, damage penalties, and lost book charges (FRS 11.13).
class FinesPage extends StatefulWidget {
  const FinesPage({super.key});

  @override
  State<FinesPage> createState() => _FinesPageState();
}

class _FinesPageState extends State<FinesPage> {
  String _status = 'outstanding';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadFines(status: _status),
    );
  }

  void _onStatusChanged(String value) {
    setState(() => _status = value);
    context.read<LibraryProvider>().loadFines(status: value);
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Fines & Penalties')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
                onSelectionChanged: (values) => _onStatusChanged(values.first),
              ),
            ),
          ),
          Expanded(
            child: libraryProvider.fines.isEmpty
                ? Center(
                    child: Text(
                      libraryProvider.finesLoading
                          ? 'Loading…'
                          : libraryProvider.errorMessage ?? 'No $_status fines',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        libraryProvider.fines.length +
                        (libraryProvider.hasMoreFines ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= libraryProvider.fines.length) {
                        return Center(
                          child: TextButton(
                            onPressed: libraryProvider.finesLoading
                                ? null
                                : () => libraryProvider.loadFines(more: true),
                            child: const Text('Load more'),
                          ),
                        );
                      }
                      final fine = libraryProvider.fines[index];
                      final isOut = fine.isOutstanding;
                      return ListTile(
                        title: Text('${fine.fineNumber} · ${fine.memberLabel}'),
                        subtitle: Text(
                          '${fineTypeLabel(fine.type)} · Total ₹${fine.amount.toStringAsFixed(2)} · Due ₹${fine.outstanding.toStringAsFixed(2)}',
                        ),
                        trailing: Chip(
                          label: Text(humanizeStatus(fine.status)),
                          backgroundColor: isOut
                              ? Theme.of(context).colorScheme.errorContainer
                              : null,
                        ),
                        onTap: () async {
                          await FineSheet.show(context, fine);
                          if (mounted) {
                            await libraryProvider.loadFines(status: _status);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
