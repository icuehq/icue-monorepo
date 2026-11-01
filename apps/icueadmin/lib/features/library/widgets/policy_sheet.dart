import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Create or edit the policy of one library and member category (FRS 11.8).
class PolicySheet extends StatefulWidget {
  const PolicySheet({super.key, this.policy});

  final LibPolicy? policy;

  static Future<void> show(BuildContext context, {LibPolicy? policy}) =>
      showInvSheet(context, () => PolicySheet(policy: policy));

  @override
  State<PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends State<PolicySheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _category = TextEditingController(
    text: widget.policy?.memberCategory,
  );
  late final _name = TextEditingController(text: widget.policy?.name);
  late final _books = TextEditingController(
    text: widget.policy?.maxBooks.toString(),
  );
  late final _days = TextEditingController(
    text: widget.policy?.loanDays.toString(),
  );
  late final _renewals = TextEditingController(
    text: widget.policy?.maxRenewals.toString() ?? '0',
  );
  late final _fine = TextEditingController(
    text: widget.policy == null || widget.policy!.fineAmount == 0
        ? ''
        : widget.policy!.fineAmount.toString(),
  );
  late final _maxFine = TextEditingController(
    text: widget.policy?.maxFine?.toString(),
  );
  late final _grace = TextEditingController(
    text: widget.policy?.graceDays.toString() ?? '0',
  );
  late String? _libraryId = widget.policy?.libraryId;
  late String _fineType = widget.policy?.fineType ?? 'none';
  late bool _canReserve = widget.policy?.canReserve ?? true;
  late bool _overdueRenewal = widget.policy?.overdueRenewal ?? false;
  late final Set<String> _restricted = {
    ...?widget.policy?.restrictedCategoryIds,
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _category,
      _name,
      _books,
      _days,
      _renewals,
      _fine,
      _maxFine,
      _grace,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _whole(String? v, {int min = 0}) {
    final n = int.tryParse(v?.trim() ?? '');
    return n == null || n < min ? 'Whole number, at least $min' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final fines = _fineType != 'none';
    await libSubmit(
      context,
      () => context.read<LibraryProvider>().savePolicy({
        'libraryId': _libraryId,
        'memberCategory': _category.text.trim().toLowerCase(),
        'name': _name.text.trim(),
        'maxBooks': int.parse(_books.text.trim()),
        'loanDays': int.parse(_days.text.trim()),
        'maxRenewals': int.parse(_renewals.text.trim()),
        'fineType': _fineType,
        'fineAmount': fines ? double.parse(_fine.text.trim()) : 0,
        'graceDays': int.parse(_grace.text.trim()),
        'maxFine': fines ? double.tryParse(_maxFine.text.trim()) : null,
        'canReserve': _canReserve,
        'overdueRenewal': _overdueRenewal,
        'restrictedCategoryIds': _restricted.toList(),
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<LibraryProvider>();
    final editing = widget.policy != null;
    final libs = [
      for (final l in p.libraries)
        if (l.active || l.id == _libraryId) l,
    ];
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _libraryId,
            decoration: const InputDecoration(labelText: 'Library *'),
            items: [
              for (final l in libs)
                DropdownMenuItem(value: l.id, child: Text(l.name)),
            ],
            onChanged: editing ? null : (v) => _libraryId = v,
            validator: (v) => v == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _category,
            enabled: !editing,
            decoration: const InputDecoration(
              labelText: 'Member category *',
              helperText: 'e.g. primary, secondary, teacher',
            ),
            validator: (v) =>
                RegExp(r'^[a-zA-Z0-9_-]{1,30}$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Letters, digits, - or _',
          ),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Policy name *'),
            validator: requiredText,
          ),
          Row(
            children: [
              for (final f in [
                (_books, 'Max books *', 1),
                (_days, 'Loan days *', 1),
                (_renewals, 'Renewals *', 0),
              ])
                Expanded(
                  child: TextFormField(
                    controller: f.$1,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: f.$2),
                    validator: (v) => _whole(v, min: f.$3),
                  ),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: _fineType,
            decoration: const InputDecoration(labelText: 'Fine'),
            items: [
              for (final e in fineTypes.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _fineType = v!),
          ),
          if (_fineType != 'none')
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fine,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount *'),
                    validator: (v) =>
                        (double.tryParse(v?.trim() ?? '') ?? 0) > 0
                        ? null
                        : 'Enter an amount',
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _maxFine,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max fine'),
                    validator: optionalNumber,
                  ),
                ),
              ],
            ),
          TextFormField(
            controller: _grace,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Grace days'),
            validator: _whole,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('May reserve books'),
            value: _canReserve,
            onChanged: (v) => setState(() => _canReserve = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('May renew when overdue'),
            value: _overdueRenewal,
            onChanged: (v) => setState(() => _overdueRenewal = v),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Restricted categories'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final c in p.categories)
                FilterChip(
                  label: Text(c.name),
                  selected: _restricted.contains(c.id),
                  onSelected: (v) => setState(
                    () => v ? _restricted.add(c.id) : _restricted.remove(c.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
