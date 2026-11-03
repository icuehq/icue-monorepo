import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_sheet.dart';

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
    final libraryProvider = context.read<LibraryProvider>();
    final personErpId = int.tryParse(_erpId.text.trim());
    if (personErpId == null) {
      return showMessage(context, 'Enter the member ERP ID first');
    }
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    if (copy == null) return showMessage(context, 'No copy found for "$code"');
    final ok = await libraryProvider.issueLoan({
      'memberId': '${_type}_$personErpId',
      'copyId': copy.id,
    });
    if (!mounted) return;
    showMessage(
      context,
      ok
          ? '${copy.accessionNumber} issued'
          : libraryProvider.errorMessage ?? 'Failed',
    );
  }

  Future<void> _find(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    if (copy == null) return showMessage(context, 'No copy found for "$code"');
    final loan = await libraryProvider.activeLoanOf(copy.id);
    if (!mounted) return;
    if (loan == null) {
      return showMessage(context, '${copy.accessionNumber} is not on loan');
    }
    await _open(loan);
  }

  Future<void> _open(LibraryLoan loan) async {
    final book = await context.read<LibraryProvider>().book(loan.catalogueId);
    if (!mounted) return;
    await LoanSheet.show(context, loan, book?.title ?? loan.accessionNumber);
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final today = todayIST();
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
                      onSelectionChanged: (values) =>
                          setState(() => _type = values.first),
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
            child: libraryProvider.loans.isEmpty
                ? Center(
                    child: Text(
                      libraryProvider.loansLoading
                          ? 'Loading…'
                          : libraryProvider.errorMessage ?? 'Nothing on loan',
                    ),
                  )
                : ListView(
                    children: [
                      for (final loan in libraryProvider.loans)
                        ListTile(
                          title: Text(
                            '${loan.accessionNumber} · ${loan.memberLabel}',
                          ),
                          subtitle: Text(
                            'Due ${loan.dueDate} · ${loan.number}',
                          ),
                          trailing: loan.overdueOn(today) > 0
                              ? Text(
                                  '${loan.overdueOn(today)}d late',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                )
                              : null,
                          onTap: () => _open(loan),
                        ),
                      if (libraryProvider.hasMoreLoans)
                        TextButton(
                          onPressed: libraryProvider.loansLoading
                              ? null
                              : () => libraryProvider.loadLoans(more: true),
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
