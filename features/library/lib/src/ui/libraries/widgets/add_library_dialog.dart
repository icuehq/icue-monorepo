import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class AddLibraryDialog extends StatefulWidget {
  const AddLibraryDialog({super.key, this.library});

  final SchoolLibrary? library;

  static Future<void> show(BuildContext context, {SchoolLibrary? library}) =>
      showFormPage(context, () => AddLibraryDialog(library: library));

  @override
  State<AddLibraryDialog> createState() => _AddLibraryDialogState();
}

class _AddLibraryDialogState extends State<AddLibraryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.library?.name);
  late final _location = TextEditingController(text: widget.library?.location);
  late final _hours = TextEditingController(text: widget.library?.hours);
  late int? _campus = widget.library?.campusId;
  int _nextSample = 0;
  bool _busy = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final access = context.read<LibraryProvider>().access;
    if (_campus == null && access.campusIds.length == 1) {
      _campus = access.campusIds.first;
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _location, _hours]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills the form with the next sample whose name is not taken yet (debug builds, new libraries only).
  void _fillSample() {
    final taken = {
      for (final library in context.read<LibraryProvider>().libraries)
        library.name.trim().toLowerCase(),
    };
    for (var tried = 0; tried < _sampleLibraries.length; tried++) {
      final sample = _sampleLibraries[_nextSample++ % _sampleLibraries.length];
      if (taken.contains(sample.name.toLowerCase())) continue;
      setState(() {
        _name.text = sample.name;
        _location.text = sample.location;
        _hours.text = sample.hours;
      });
      return;
    }
    setState(() => _errorMessage = 'All sample libraries already exist');
  }

  /// Required, and unique among libraries (compared ignoring case).
  String? _validateName(String? value) {
    final required = requiredText(value);
    if (required != null) return required;
    final name = value!.trim().toLowerCase();
    final exists = context.read<LibraryProvider>().libraries.any(
      (library) =>
          library.id != widget.library?.id &&
          library.name.trim().toLowerCase() == name,
    );
    return exists ? '"${value.trim()}" already exists' : null;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final schoolLibrary = widget.library;
    final provider = context.read<LibraryProvider>();
    final saved = await submitAndClose<LibraryProvider>(
      context,
      () => provider.saveLibrary({
        if (schoolLibrary != null) 'id': schoolLibrary.id,
        'name': _name.text.trim(),
        'campusId': _campus,
        'location': blankToNull(_location),
        'hours': blankToNull(_hours),
      }),
    );
    if (mounted && !saved) {
      setState(() {
        _busy = false;
        _errorMessage = provider.errorMessage ?? 'Could not save library';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = context.read<LibraryProvider>().access;
    final editing = widget.library != null;
    final campuses = {...access.campusIds, ?_campus}.toList();

    // With one campus there is nothing to choose.
    final askCampus = campuses.length > 1;

    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_library_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? 'Edit Library' : 'New Library',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      editing ? 'Update the name, location and schedule.' : 'Set up a new library branch and operating schedule.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode && !editing)
                TextButton.icon(
                  onPressed: _busy ? null : _fillSample,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Fill sample'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Error Callout
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 1: Basic Details
          _DialogSection(
            title: 'Library Details',
            icon: Icons.badge_outlined,
            children: [
              AppTextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: _validateName,
                label: 'Library name *',
                hintText: 'e.g. Central Campus Library',
                icon: Icons.business_outlined,
              ),
              if (askCampus) ...[
                const SizedBox(height: 14),
                _buildCampusField(editing, campuses),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Location & Schedule
          _DialogSection(
            title: 'Location & Operating Schedule',
            icon: Icons.place_outlined,
            children: [
              _buildLocationField(),
              const SizedBox(height: 14),
              _buildHoursField(),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _busy
                      ? 'Saving…'
                      : (editing ? 'Save changes' : 'Create library'),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampusField(bool editing, List<int> campuses) {
    return AppDropdown<int>(
      value: _campus,
      items: [
        for (final value in campuses)
          DropdownMenuItem(value: value, child: Text('Campus $value')),
      ],
      onChanged: editing ? null : (value) => setState(() => _campus = value),
      validator: (value) => value == null ? 'Campus is required' : null,
      label: 'Campus *',
      icon: Icons.school_outlined,
    );
  }

  Widget _buildLocationField() {
    return AppTextField(
      controller: _location,
      textInputAction: TextInputAction.next,
      label: 'Location',
      hintText: 'e.g. Building A, 2nd Floor',
      icon: Icons.location_on_outlined,
    );
  }

  Widget _buildHoursField() {
    return AppTextField(
      controller: _hours,
      textInputAction: TextInputAction.next,
      label: 'Opening hours',
      hintText: 'e.g. Mon–Fri 8 AM – 5 PM',
      icon: Icons.schedule_outlined,
    );
  }
}

const _sampleLibraries = [
  (
    name: 'Central Library',
    location: 'Main block, Ground floor',
    hours: 'Mon–Sat, 8:00 AM – 4:00 PM',
  ),
  (
    name: 'Junior Reading Room',
    location: 'Primary wing, 1st floor',
    hours: 'Mon–Fri, 9:00 AM – 3:00 PM',
  ),
  (
    name: 'Science Resource Centre',
    location: 'Science block, 2nd floor',
    hours: 'Mon–Fri, 8:30 AM – 5:00 PM',
  ),
  (
    name: 'Teachers\' Reference Library',
    location: 'Staff room annexe',
    hours: 'Mon–Sat, 9:00 AM – 5:00 PM',
  ),
];

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
