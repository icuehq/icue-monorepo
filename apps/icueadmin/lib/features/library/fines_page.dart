import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/fine_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

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

  void _onStatusChanged(String s) {
    setState(() => _status = s);
    context.read<LibraryProvider>().loadFines(status: s);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
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
                onSelectionChanged: (s) => _onStatusChanged(s.first),
              ),
            ),
          ),
          Expanded(
            child: p.fines.isEmpty
                ? Center(
                    child: Text(
                      p.finesLoading
                          ? 'Loading…'
                          : p.errorMessage ?? 'No $_status fines',
                    ),
                  )
                : ListView.builder(
                    itemCount: p.fines.length + (p.hasMoreFines ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= p.fines.length) {
                        return Center(
                          child: TextButton(
                            onPressed: p.finesLoading
                                ? null
                                : () => p.loadFines(more: true),
                            child: const Text('Load more'),
                          ),
                        );
                      }
                      final f = p.fines[index];
                      final isOut = f.isOutstanding;
                      return ListTile(
                        title: Text('${f.fineNumber} · ${f.memberLabel}'),
                        subtitle: Text(
                          '${fineTypeLabel(f.type)} · Total ₹${f.amount.toStringAsFixed(2)} · Due ₹${f.outstanding.toStringAsFixed(2)}',
                        ),
                        trailing: Chip(
                          label: Text(fineStatusLabel(f.status)),
                          backgroundColor: isOut
                              ? Theme.of(context).colorScheme.errorContainer
                              : null,
                        ),
                        onTap: () async {
                          await FineSheet.show(context, f);
                          if (mounted) {
                            await p.loadFines(status: _status);
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
