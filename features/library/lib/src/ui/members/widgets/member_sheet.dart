import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_ui.dart';

/// Enrol a student or teacher, or edit their category, libraries and dates (FRS 11.7).
class MemberSheet extends StatefulWidget {
  const MemberSheet({super.key, this.member, this.type, this.personErpId});

  final LibraryMember? member;
  final String? type;
  final int? personErpId;

  static Future<void> show(
    BuildContext context, {
    LibraryMember? member,
    String? type,
    int? personErpId,
  }) => showFormSheet(
    context,
    () => MemberSheet(member: member, type: type, personErpId: personErpId),
  );

  @override
  State<MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<MemberSheet> {
  final _form = GlobalKey<FormState>();
  final _requestId = newRequestId();
  late final _erpId = TextEditingController(
    text: (widget.member?.personErpId ?? widget.personErpId)?.toString(),
  );
  late final _class = TextEditingController(
    text: widget.member?.classId?.toString(),
  );
  late final _category = TextEditingController(
    text: widget.member?.memberCategory,
  );
  late final _start = TextEditingController(
    text: widget.member?.start ?? todayIST(),
  );
  late final _end = TextEditingController(text: widget.member?.end);
  late String _type = widget.member?.memberType ?? widget.type ?? 'student';
  late final Set<String> _libraries = {...?widget.member?.libraryIds};
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_erpId, _class, _category, _start, _end]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_libraries.isEmpty) {
      showMessage(context, 'Pick at least one library');
      return;
    }
    setState(() => _busy = true);
    await submitAndClose<LibraryProvider>(
      context,
      () => context.read<LibraryProvider>().saveMember({
        'memberType': _type,
        'personErpId': int.parse(_erpId.text.trim()),
        'classId': _type == 'student' ? int.tryParse(_class.text.trim()) : null,
        'memberCategory': _category.text.trim().toLowerCase(),
        'libraryIds': _libraries.toList(),
        'start': _start.text,
        'end': blankToNull(_end),
      }, requestId: _requestId),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
    final editing = widget.member != null;
    final categories = {
      for (final policy in libraryProvider.policies) policy.memberCategory,
    }.toList()..sort();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'student', label: Text('Student')),
              ButtonSegment(value: 'teacher', label: Text('Teacher')),
            ],
            selected: {_type},
            onSelectionChanged: editing || widget.type != null
                ? null
                : (values) => setState(() => _type = values.first),
          ),
          // ponytail: ERP IDs typed in; a student/staff picker needs the Node endpoints.
          TextFormField(
            controller: _erpId,
            enabled: !editing && widget.personErpId == null,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ERP ID *'),
            validator: (value) => (int.tryParse(value?.trim() ?? '') ?? 0) > 0
                ? null
                : 'Enter the ERP ID',
          ),
          if (_type == 'student')
            TextFormField(
              controller: _class,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Class ID'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ||
                      int.tryParse(value!.trim()) != null
                  ? null
                  : 'Enter a number',
            ),
          TextFormField(
            controller: _category,
            decoration: InputDecoration(
              labelText: 'Member category *',
              helperText: categories.isEmpty
                  ? 'Must match a borrowing policy'
                  : 'Policies exist for: ${categories.join(', ')}',
            ),
            validator: (value) =>
                RegExp(r'^[a-zA-Z0-9_-]{1,30}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Letters, digits, - or _',
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Libraries *'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final schoolLibrary in libraryProvider.libraries)
                if (schoolLibrary.active ||
                    _libraries.contains(schoolLibrary.id))
                  FilterChip(
                    label: Text(schoolLibrary.name),
                    selected: _libraries.contains(schoolLibrary.id),
                    onSelected: (value) => setState(
                      () => value
                          ? _libraries.add(schoolLibrary.id)
                          : _libraries.remove(schoolLibrary.id),
                    ),
                  ),
            ],
          ),
          LibraryDateField(
            controller: _start,
            label: 'Member from',
            required: true,
          ),
          LibraryDateField(controller: _end, label: 'Member until'),
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
