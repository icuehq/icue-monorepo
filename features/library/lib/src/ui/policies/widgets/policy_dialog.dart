import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Create or edit the policy of one library and member category (FRS 11.8).
class PolicyDialog extends StatefulWidget {
  const PolicyDialog({super.key, this.policy});

  final LibraryPolicy? policy;

  static Future<void> show(BuildContext context, {LibraryPolicy? policy}) =>
      showFormPage(context, () => PolicyDialog(policy: policy));

  @override
  State<PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<PolicyDialog> {
  final _form = GlobalKey<FormState>();
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
  late final Set<String> _categories = {...?widget.policy?.categoryIds};
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
        'id': ?widget.policy?.id,
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
        'categoryIds': _categories.toList(),
      }),
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
    final theme = Theme.of(context);
    const gap = SizedBox(width: 12);
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IcueFormSectionCard(
            title: 'Applies to',
            icon: Icons.groups_outlined,
            children: [
              IcueDropdown<String>(
                value: _libraryId,
                items: [
                  for (final schoolLibrary in libraries)
                    DropdownMenuItem(
                      value: schoolLibrary.id,
                      child: Text(schoolLibrary.name),
                    ),
                ],
                onChanged: editing ? null : (value) => _libraryId = value,
                validator: (value) => value == null ? 'Required' : null,
                label: 'Library *',
              ),
              IcueDropdown<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Students')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Everyone (default)'),
                  ),
                ],
                onChanged: editing ? null : (value) => _type = value,
                validator: (value) => value == null ? 'Required' : null,
                label: 'Members *',
              ),
              IcueTextField(
                controller: _name,
                validator: requiredText,
                label: 'Policy name *',
              ),
            ],
          ),
          IcueFormSectionCard(
            title: 'Loan rules',
            icon: Icons.menu_book_rounded,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, field) in [
                    (_books, 'Max books *', 1),
                    (_days, 'Loan days *', 1),
                    (_renewals, 'Renewals *', 0),
                  ].indexed) ...[
                    if (index > 0) gap,
                    Expanded(
                      child: IcueTextField(
                        controller: field.$1,
                        keyboardType: TextInputType.number,
                        validator: (value) => _whole(value, min: field.$3),
                        label: field.$2,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          IcueFormSectionCard(
            title: 'Overdue fine',
            icon: Icons.payments_outlined,
            children: [
              IcueDropdown<String>(
                value: _fineType,
                items: [
                  for (final mapEntry in fineTypes.entries)
                    DropdownMenuItem(
                      value: mapEntry.key,
                      child: Text(mapEntry.value),
                    ),
                ],
                onChanged: (value) => setState(() => _fineType = value!),
                label: 'Fine type',
              ),
              if (_fineType != 'none')
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: IcueTextField(
                        controller: _fine,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            (double.tryParse(value?.trim() ?? '') ?? 0) > 0
                            ? null
                            : 'Enter an amount',
                        label: 'Amount *',
                      ),
                    ),
                    gap,
                    Expanded(
                      child: IcueTextField(
                        controller: _maxFine,
                        keyboardType: TextInputType.number,
                        validator: optionalNumber,
                        label: 'Max fine',
                      ),
                    ),
                  ],
                ),
              IcueTextField(
                controller: _grace,
                keyboardType: TextInputType.number,
                validator: _whole,
                label: 'Grace days',
              ),
            ],
          ),
          if (libraryProvider.categories.isNotEmpty)
            IcueFormSectionCard(
              title: 'Book categories',
              icon: Icons.category_outlined,
              children: [
                Text(
                  'These rules apply to books of the selected categories. Leave all unselected to apply them to every category no other policy covers. A policy for Everyone is the default for members whose type has no policy of its own.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final category in libraryProvider.categories)
                      FilterChip(
                        label: Text(category.name),
                        selected: _categories.contains(category.id),
                        onSelected: (value) => setState(
                          () => value
                              ? _categories.add(category.id)
                              : _categories.remove(category.id),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          IcueButton(
            label: _busy ? 'Saving…' : 'Save policy',
            onPressed: _busy ? null : _save,
            leadingIcon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}
