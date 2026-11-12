import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';

/// Picks a class and section, lists its students from the ERP (Node) and reports the one tapped.
class ClassStudentChooser extends StatefulWidget {
  const ClassStudentChooser({required this.onChosen, super.key});

  final ValueChanged<LibraryPerson> onChosen;

  @override
  State<ClassStudentChooser> createState() => _ClassStudentChooserState();
}

class _ClassStudentChooserState extends State<ClassStudentChooser> {
  List<Standards> _classes = [];
  Standards? _class;
  Section? _section;
  List<StudentData> _students = [];
  bool _loading = true;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _run(() async {
      final provider = context.read<LibraryProvider>();
      await provider.loadStandards();
      _classes = provider.standards;
    });
  }

  Future<void> _run(Future<void> Function() load) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await load();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(Standards? standard, Section? section) {
    setState(() {
      _class = standard;
      _section = section;
      _students = [];
      _filter = '';
    });
    if (standard == null || section == null) return;
    _run(() async {
      final students = await context.read<LibraryProvider>().studentsOf(
        standard.id,
        section.name,
      );
      if (mounted) setState(() => _students = students);
    });
  }

  bool _matches(StudentData student) =>
      _filter.isEmpty ||
      [
        student.name,
        student.rollNo,
        student.admissionNumber,
      ].any((value) => value.toLowerCase().contains(_filter));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<Standards>(
                initialValue: _class,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  for (final standard in _classes)
                    DropdownMenuItem(
                      value: standard,
                      child: Text(standard.name),
                    ),
                ],
                onChanged: (standard) => _pick(standard, null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<Section>(
                key: ValueKey(_class?.id),
                initialValue: _section,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Section'),
                items: [
                  for (final section in _class?.sections ?? const <Section>[])
                    DropdownMenuItem(value: section, child: Text(section.name)),
                ],
                onChanged: (section) => _pick(_class, section),
              ),
            ),
          ],
        ),
        if (_students.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextField(
            onChanged: (text) =>
                setState(() => _filter = text.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search by name, roll no. or admission no.',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error))
        else if (_section != null && _students.isEmpty)
          const Text('No students in this class and section')
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final student in _students.where(_matches))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(student.name),
                    subtitle: Text(
                      [
                        if (student.rollNo.isNotEmpty) 'Roll ${student.rollNo}',
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
