import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Finds a student or teacher in the ERP (Node) by typing part of the name, then reports the choice.
class PersonPicker extends StatefulWidget {
  const PersonPicker({required this.onChanged, super.key});

  final ValueChanged<LibraryPerson?> onChanged;

  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _type = 'student';
  LibraryPerson? _chosen;
  List<LibraryPerson> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _choose(LibraryPerson? person) {
    setState(() {
      _chosen = person;
      _results = const [];
      if (person == null) _search.clear();
    });
    widget.onChanged(person);
  }

  void _changed(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _find(text));
  }

  Future<void> _find(String text) async {
    final libraryProvider = context.read<LibraryProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await libraryProvider.searchPeople(_type, text.trim());
      if (!mounted || text != _search.text) return;
      setState(() => _results = found.take(8).toList());
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not search: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teachersMissing =
        _type == 'teacher' &&
        !context.read<LibraryProvider>().teachersAvailable;
    final chosen = _chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'student', label: Text('Student')),
            ButtonSegment(value: 'teacher', label: Text('Teacher')),
          ],
          selected: {_type},
          onSelectionChanged: (values) {
            setState(() => _type = values.first);
            _search.clear();
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
        else if (teachersMissing)
          // TODO(teachers): remove once the Node teacher search is connected.
          Text(
            'Teacher lookup is not connected yet.',
            style: theme.textTheme.bodySmall,
          )
        else ...[
          TextField(
            controller: _search,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: 'Search by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
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
          for (final person in _results)
            ListTile(
              dense: true,
              title: Text(person.name),
              subtitle: person.detail.isEmpty ? null : Text(person.detail),
              onTap: () => _choose(person),
            ),
        ],
      ],
    );
  }
}
