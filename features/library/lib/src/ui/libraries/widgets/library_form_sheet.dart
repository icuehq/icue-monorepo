import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibraryFormSheet extends StatefulWidget {
  const LibraryFormSheet({super.key, this.library});

  final SchoolLibrary? library;

  static Future<void> show(BuildContext context, {SchoolLibrary? library}) =>
      showFormPage(context, () => LibraryFormSheet(library: library));

  @override
  State<LibraryFormSheet> createState() => _LibraryFormSheetState();
}

class _LibraryFormSheetState extends State<LibraryFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.library?.name);
  late final _description = TextEditingController(
    text: widget.library?.description,
  );
  late final _location = TextEditingController(text: widget.library?.location);
  late final _phone = TextEditingController(text: widget.library?.phone);
  late final _email = TextEditingController(text: widget.library?.email);
  late final _hours = TextEditingController(text: widget.library?.hours);
  late int? _campus = widget.library?.campusId;
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
    for (final controller in [
      _name,
      _description,
      _location,
      _phone,
      _email,
      _hours,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Optional; 7 to 15 digits, with an optional leading + and spaces, dashes or brackets between them.
  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^\+?\d{7,15}$').hasMatch(digits)
        ? null
        : 'Enter a valid phone number';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Enter a valid email address';
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
        'description': blankToNull(_description),
        'location': blankToNull(_location),
        'phone': blankToNull(_phone),
        'email': blankToNull(_email),
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

    final isMultiCol = context.isWide;
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
                      editing
                          ? 'Update the name, location, schedule and contact details.'
                          : 'Set up a new library branch and operating schedule.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
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
          _FormSection(
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
          _FormSection(
            title: 'Location & Operating Schedule',
            icon: Icons.place_outlined,
            children: [
              if (isMultiCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLocationField()),
                    const SizedBox(width: 14),
                    Expanded(child: _buildHoursField()),
                  ],
                )
              else ...[
                _buildLocationField(),
                const SizedBox(height: 14),
                _buildHoursField(),
              ],
              const SizedBox(height: 14),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3: Contact & notes
          _FormSection(
            title: 'Contact & Notes',
            icon: Icons.contact_phone_outlined,
            children: [
              if (isMultiCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPhoneField()),
                    const SizedBox(width: 14),
                    Expanded(child: _buildEmailField()),
                  ],
                )
              else ...[
                _buildPhoneField(),
                const SizedBox(height: 14),
                _buildEmailField(),
              ],
              const SizedBox(height: 14),
              AppTextField(
                controller: _description,
                minLines: 2,
                maxLines: 3,
                label: 'Description / Notes',
                hintText: 'Additional details about collections, rules…',
                icon: Icons.notes_rounded,
              ),
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

  Widget _buildPhoneField() {
    return AppTextField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: _validatePhone,
      label: 'Phone',
      hintText: 'e.g. +91 98765 43210',
      icon: Icons.call_outlined,
    );
  }

  Widget _buildEmailField() {
    return AppTextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: _validateEmail,
      label: 'Email',
      hintText: 'e.g. library@school.edu',
      icon: Icons.mail_outline_rounded,
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

class _FormSection extends StatelessWidget {
  const _FormSection({
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
