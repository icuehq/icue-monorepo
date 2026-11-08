import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/class_student_chooser.dart';

/// Finds a student or staff member in the ERP (Node) by admission number, then reports the choice.
class PersonPicker extends StatefulWidget {
  const PersonPicker({
    required this.onChanged,
    this.autofocus = false,
    super.key,
  });

  final ValueChanged<LibraryPerson?> onChanged;
  final bool autofocus;

  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  final _admissionNumber = TextEditingController();
  final _focusNode = FocusNode();
  String _type = 'student';
  String _mode = 'number';
  LibraryPerson? _chosen;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _focusNode.dispose();
    _admissionNumber.dispose();
    super.dispose();
  }

  void _choose(LibraryPerson? person) {
    setState(() {
      _chosen = person;
      _error = null;
      if (person == null) _admissionNumber.clear();
    });
    widget.onChanged(person);
    if (person == null) _focusNode.requestFocus();
  }

  Future<void> _find(String text) async {
    final number = text.trim();
    if (number.isEmpty) return;
    final libraryProvider = context.read<LibraryProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final person = await libraryProvider.findPerson(_type, number);
      if (!mounted) return;
      if (person == null) {
        final identifier = _type == 'student' ? 'admission number' : 'staff ID';
        setState(() => _error = 'No $_label found with $identifier "$number"');
        _focusNode.requestFocus();
      } else {
        _choose(person);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not look up: $error');
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _label => _type == 'student' ? 'student' : 'staff member';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = _chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'student', label: Text('Student')),
            ButtonSegment(value: 'teacher', label: Text('Staff')),
          ],
          selected: {_type},
          onSelectionChanged: (values) {
            setState(() => _type = values.first);
            _choose(null);
          },
        ),
        const SizedBox(height: 8),
        if (chosen != null)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(chosen.name),
              subtitle: Text(
                [
                  'ID ${chosen.personErpId}',
                  if (chosen.detail.isNotEmpty) chosen.detail,
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Choose someone else',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _choose(null),
              ),
            ),
          )
        else if (_type == 'student')
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'number', label: Text('Admission no.')),
              ButtonSegment(value: 'class', label: Text('Class')),
            ],
            selected: {_mode},
            onSelectionChanged: (values) =>
                setState(() => _mode = values.first),
          ),
        if (chosen == null && _type == 'student') const SizedBox(height: 8),
        if (chosen == null && _type == 'student' && _mode == 'class')
          ClassStudentChooser(onChosen: _choose)
        else if (chosen == null) ...[
          TextField(
            controller: _admissionNumber,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            enabled: !_loading,
            keyboardType: _type == 'teacher' ? TextInputType.number : null,
            textInputAction: TextInputAction.search,
            onSubmitted: _find,
            decoration: InputDecoration(
              hintText: _type == 'student'
                  ? 'Enter admission number'
                  : 'Enter staff ID (ERP ID)',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Find',
                      icon: const Icon(Icons.search),
                      onPressed: () => _find(_admissionNumber.text),
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ],
    );
  }
}
