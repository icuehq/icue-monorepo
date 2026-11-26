import 'package:flutter/material.dart';

/// A person picked by ERP ID.
class StaffOption {
  const StaffOption({required this.id});

  final int id;
}

String staffDisplayName(int staffId) => 'Staff #$staffId';

/// Picks a person by ERP ID. Node has no staff lookup yet, so names cannot be searched;
/// ponytail: swap for a name search (like Library's person picker) when that endpoint exists.
class PersonSearchField extends StatefulWidget {
  const PersonSearchField({
    required this.label,
    required this.onSelected,
    this.hint = 'Enter the ERP ID',
    this.exclude = const {},
    this.clearOnSelect = false,
    super.key,
  });

  final String label;
  final String hint;
  final Set<int> exclude;
  final bool clearOnSelect;
  final ValueChanged<StaffOption> onSelected;

  @override
  State<PersonSearchField> createState() => _PersonSearchFieldState();
}

class _PersonSearchFieldState extends State<PersonSearchField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final id = int.tryParse(_controller.text.trim());
    if (id == null || id <= 0) {
      setState(() => _error = 'Enter a numeric ERP ID');
      return;
    }
    if (widget.exclude.contains(id)) {
      setState(() => _error = 'Already added');
      return;
    }
    setState(() => _error = null);
    widget.onSelected(StaffOption(id: id));
    if (widget.clearOnSelect) _controller.clear();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => _submit(),
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText:
          'Name search needs the staff directory, which is not connected yet.',
      errorText: _error,
      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
      suffixIcon: IconButton(
        tooltip: 'Add',
        icon: const Icon(Icons.check_rounded),
        onPressed: _submit,
      ),
    ),
  );
}
