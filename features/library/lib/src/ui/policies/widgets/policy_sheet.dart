import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Create or edit the policy of one library and member category (FRS 11.8).
class PolicySheet extends StatefulWidget {
  const PolicySheet({super.key, this.policy});

  final LibraryPolicy? policy;

  static Future<void> show(BuildContext context, {LibraryPolicy? policy}) =>
      showFormPage(context, () => PolicySheet(policy: policy));

  @override
  State<PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends State<PolicySheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late String? _type = widget.policy?.memberType;
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
    for (final controller in [
      _name,
      _books,
      _days,
      _renewals,
      _fine,
      _maxFine,
      _grace,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _whole(String? value, {int min = 0}) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < min
        ? 'Whole number, at least $min'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final fines = _fineType != 'none';
    await submitAndClose<LibraryProvider>(
      context,
      () => context.read<LibraryProvider>().savePolicy({
        'libraryId': _libraryId,
        'memberType': _type,
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
    final libraryProvider = context.read<LibraryProvider>();
    final editing = widget.policy != null;
    final libraries = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active || schoolLibrary.id == _libraryId)
          schoolLibrary,
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
              for (final schoolLibrary in libraries)
                DropdownMenuItem(
                  value: schoolLibrary.id,
                  child: Text(schoolLibrary.name),
                ),
            ],
            onChanged: editing ? null : (value) => _libraryId = value,
            validator: (value) => value == null ? 'Required' : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Applies to *'),
            items: const [
              DropdownMenuItem(value: 'student', child: Text('Students')),
              DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
            ],
            onChanged: editing ? null : (value) => _type = value,
            validator: (value) => value == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Policy name *'),
            validator: requiredText,
          ),
          Row(
            children: [
              for (final field in [
                (_books, 'Max books *', 1),
                (_days, 'Loan days *', 1),
                (_renewals, 'Renewals *', 0),
              ])
                Expanded(
                  child: TextFormField(
                    controller: field.$1,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: field.$2),
                    validator: (value) => _whole(value, min: field.$3),
                  ),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: _fineType,
            decoration: const InputDecoration(labelText: 'Fine'),
            items: [
              for (final mapEntry in fineTypes.entries)
                DropdownMenuItem(
                  value: mapEntry.key,
                  child: Text(mapEntry.value),
                ),
            ],
            onChanged: (value) => setState(() => _fineType = value!),
          ),
          if (_fineType != 'none')
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fine,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount *'),
                    validator: (value) =>
                        (double.tryParse(value?.trim() ?? '') ?? 0) > 0
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
            onChanged: (value) => setState(() => _canReserve = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('May renew when overdue'),
            value: _overdueRenewal,
            onChanged: (value) => setState(() => _overdueRenewal = value),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Restricted categories'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final category in libraryProvider.categories)
                FilterChip(
                  label: Text(category.name),
                  selected: _restricted.contains(category.id),
                  onSelected: (value) => setState(
                    () => value
                        ? _restricted.add(category.id)
                        : _restricted.remove(category.id),
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
