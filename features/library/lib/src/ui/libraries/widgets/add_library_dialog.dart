import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/mock_books.dart';

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
  int _nextSample = 0;
  bool _busy = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in [_name, _location, _hours]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fills the form with the next sample whose name is not taken yet (non-prod builds, new libraries only).
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
    final editing = widget.library != null;

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
              if (showSampleData && !editing)
                IcueButton(
                  label: 'Fill sample',
                  onPressed: _busy ? null : _fillSample,
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.auto_fix_high_rounded,
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
              IcueTextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: _validateName,
                label: 'Library name *',
                hintText: 'e.g. Central Library',
                icon: Icons.business_outlined,
              ),
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
              IcueButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                variant: IcueButtonVariant.outline,
              ),
              const SizedBox(width: 12),
              IcueButton(
                label: _busy
                    ? 'Saving…'
                    : (editing ? 'Save changes' : 'Create library'),
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.check_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    return IcueTextField(
      controller: _location,
      textInputAction: TextInputAction.next,
      label: 'Location',
      hintText: 'e.g. Building A, 2nd Floor',
      icon: Icons.location_on_outlined,
    );
  }

  Widget _buildHoursField() {
    return IcueTextField(
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
