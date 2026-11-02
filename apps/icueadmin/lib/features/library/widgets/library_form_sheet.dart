import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibraryFormSheet extends StatefulWidget {
  const LibraryFormSheet({super.key, this.library});

  final SchoolLibrary? library;

  static Future<void> show(BuildContext context, {SchoolLibrary? library}) =>
      showFormSheet(context, () => LibraryFormSheet(library: library));

  @override
  State<LibraryFormSheet> createState() => _LibraryFormSheetState();
}

class _LibraryFormSheetState extends State<LibraryFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.library?.code);
  late final _name = TextEditingController(text: widget.library?.name);
  late final _description = TextEditingController(
    text: widget.library?.description,
  );
  late final _location = TextEditingController(text: widget.library?.location);
  late final _contact = TextEditingController(text: widget.library?.contact);
  late final _hours = TextEditingController(text: widget.library?.hours);
  // ponytail: ERP staff IDs typed in; a staff picker needs the Node staff endpoint.
  late final _staff = TextEditingController(
    text: widget.library?.staffIds.join(', '),
  );
  late int? _campus = widget.library?.campusId;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _description,
      _location,
      _contact,
      _hours,
      _staff,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _staffError(String? currentValue) =>
      splitList(currentValue ?? '')
          .every((value) => int.tryParse(value) != null)
      ? null
      : 'Comma-separated staff IDs';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final schoolLibrary = widget.library;
    await submitAndClose<LibraryProvider>(
      context,
      () => context.read<LibraryProvider>().saveLibrary({
        if (schoolLibrary != null)
          'id': schoolLibrary.id
        else
          'code': _code.text.trim(),
        'name': _name.text.trim(),
        'campusId': _campus,
        'description': blankToNull(_description),
        'location': blankToNull(_location),
        'contact': blankToNull(_contact),
        'hours': blankToNull(_hours),
        'staffIds': [
          for (final value in splitList(_staff.text)) int.parse(value),
        ],
      }),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final access = context.read<LibraryProvider>().access;
    final editing = widget.library != null;
    final campuses = {...access.campusIds, ?_campus}.toList();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _code,
            enabled: !editing,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Library code *'),
            validator: requiredText,
          ),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Library name *'),
            validator: requiredText,
          ),
          DropdownButtonFormField<int>(
            initialValue: _campus,
            decoration: const InputDecoration(labelText: 'Campus *'),
            items: [
              for (final value in campuses)
                DropdownMenuItem(value: value, child: Text('Campus $value')),
            ],
            onChanged: editing ? null : (value) => _campus = value,
            validator: (value) => value == null ? 'Required' : null,
          ),
          TextFormField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          TextFormField(
            controller: _hours,
            decoration: const InputDecoration(labelText: 'Opening hours'),
          ),
          TextFormField(
            controller: _contact,
            decoration: const InputDecoration(labelText: 'Contact details'),
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextFormField(
            controller: _staff,
            decoration: const InputDecoration(labelText: 'Librarian staff IDs'),
            validator: _staffError,
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
