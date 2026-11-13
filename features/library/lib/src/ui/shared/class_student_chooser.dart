import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/person_list_tile.dart';

/// Picks a class (or, with [staff], a staff group) and section, lists its people from the ERP (Node) and reports the one tapped.
class ClassStudentChooser extends StatefulWidget {
  const ClassStudentChooser({
    required this.onChosen,
    this.staff = false,
    super.key,
  });

  final bool staff;
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
      _classes = [
        for (final standard in provider.standards)
          if (widget.staff ? standard.isStaff : standard.isStudent) standard,
      ];
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
    if (standard == null) return;
    // No section yet: the whole class, across all its sections.
    final sections = section == null
        ? [for (final classSection in standard.sections) classSection.name]
        : [section.name];
    _run(() async {
      final students = await context.read<LibraryProvider>().studentsOf(
        standard.id,
        sections,
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
    final visible = _students.where(_matches).toList();
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
                decoration: InputDecoration(
                  labelText: widget.staff ? 'Group' : 'Class',
                ),
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
            decoration: InputDecoration(
              hintText: widget.staff
                  ? 'Search by name or staff no.'
                  : 'Search by name, roll no. or admission no.',
              prefixIcon: const Icon(Icons.search),
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
        else if (_class != null && _students.isEmpty)
          Text(
            widget.staff
                ? 'No staff in this group'
                : 'No students in this class',
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final student = visible[index];
                return PersonListTile(
                  name: student.name,
                  photoUrl: student.photoUrl,
                  chips: [
                    if (!widget.staff && student.rollNo.isNotEmpty)
                      'Roll ${student.rollNo}',
                    if (student.admissionNumber.isNotEmpty)
                      '${widget.staff ? 'Staff no.' : 'Adm.'} ${student.admissionNumber}',
                  ],
                  onTap: () => widget.onChosen(
                    context.read<LibraryProvider>().studentPerson(
                      student,
                      staff: widget.staff,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
