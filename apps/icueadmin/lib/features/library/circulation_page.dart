import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/features/library/widgets/loan_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Issue, return and renew (FRS 11.9–11.11): scan a copy to issue it to the typed member, or to take it back.
class CirculationPage extends StatefulWidget {
  const CirculationPage({super.key});

  @override
  State<CirculationPage> createState() => _CirculationPageState();
}

class _CirculationPageState extends State<CirculationPage> {
  final _erpId = TextEditingController();
  String _type = 'student';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadLoans(),
    );
  }

  @override
  void dispose() {
    _erpId.dispose();
    super.dispose();
  }

  Future<void> _issue(String code) async {
    final p = context.read<LibraryProvider>();
    final erp = int.tryParse(_erpId.text.trim());
    if (erp == null) return invSnack(context, 'Enter the member ERP ID first');
    final copy = await p.findCopy(code);
    if (!mounted) return;
    if (copy == null) return invSnack(context, 'No copy found for "$code"');
    final ok = await p.issueLoan({
      'memberId': '${_type}_$erp',
      'copyId': copy.id,
    });
    if (!mounted) return;
    invSnack(
      context,
      ok ? '${copy.accessionNo} issued' : p.errorMessage ?? 'Failed',
    );
  }

  Future<void> _find(String code) async {
    final p = context.read<LibraryProvider>();
    final copy = await p.findCopy(code);
    if (!mounted) return;
    if (copy == null) return invSnack(context, 'No copy found for "$code"');
    final loan = await p.activeLoanOf(copy.id);
    if (!mounted) return;
    if (loan == null) {
      return invSnack(context, '${copy.accessionNo} is not on loan');
    }
    await _open(loan);
  }

  Future<void> _open(LibLoan loan) async {
    final book = await context.read<LibraryProvider>().book(loan.catalogueId);
    if (!mounted) return;
    await LoanSheet.show(context, loan, book?.title ?? loan.accessionNo);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return Scaffold(
      appBar: AppBar(title: const Text('Circulation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'student', label: Text('Student')),
                        ButtonSegment(value: 'teacher', label: Text('Teacher')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _erpId,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'ERP ID'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ScanField(
                  hint: 'Scan book to ISSUE to this member',
                  onScan: _issue,
                  clearOnScan: true,
                ),
                const SizedBox(height: 8),
                ScanField(
                  hint: 'Scan book to RETURN or RENEW',
                  onScan: _find,
                  clearOnScan: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: p.loans.isEmpty
                ? Center(
                    child: Text(
                      p.loansLoading
                          ? 'Loading…'
                          : p.errorMessage ?? 'Nothing on loan',
                    ),
                  )
                : ListView(
                    children: [
                      for (final l in p.loans)
                        ListTile(
                          title: Text('${l.accessionNo} · ${l.memberLabel}'),
                          subtitle: Text('Due ${l.dueOn} · ${l.number}'),
                          trailing: l.overdueOn(today) > 0
                              ? Text(
                                  '${l.overdueOn(today)}d late',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                )
                              : null,
                          onTap: () => _open(l),
                        ),
                      if (p.hasMoreLoans)
                        TextButton(
                          onPressed: p.loansLoading
                              ? null
                              : () => p.loadLoans(more: true),
                          child: const Text('Load more'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
