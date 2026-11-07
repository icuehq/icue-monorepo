import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';

/// Searches students in the ERP (Node) by name or admission number and reports the one tapped.
class StudentSearchChooser extends StatefulWidget {
  const StudentSearchChooser({required this.onChosen, super.key});

  final ValueChanged<LibraryPerson> onChosen;

  @override
  State<StudentSearchChooser> createState() => _StudentSearchChooserState();
}

class _StudentSearchChooserState extends State<StudentSearchChooser> {
  List<StudentData>? _results;
  bool _loading = false;
  String? _error;

  Future<void> _search(String text) async {
    if (text.trim().isEmpty) return;
    final provider = context.read<LibraryProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await provider.searchStudents(text);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not search: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: const InputDecoration(
            hintText: 'Search by name or admission number',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (results != null && results.isEmpty)
          const Text('No students found')
        else if (results != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final student in results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(student.name),
                    subtitle: Text(
                      [
                        if (student.standard.isNotEmpty)
                          'Class ${student.standard} ${student.section}'.trim(),
                        if (student.admissionNumber.isNotEmpty)
                          'Adm. ${student.admissionNumber}',
                      ].join(' · '),
                    ),
                    onTap: () => widget.onChosen(
                      context.read<LibraryProvider>().studentPerson(student),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
