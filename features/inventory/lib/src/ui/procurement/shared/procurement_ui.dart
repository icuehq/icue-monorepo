import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows the document number and (when [close]) leaves the screen.
/// No fixed request ID: each tap is its own action (a saved draft is later submitted).
Future<bool> procSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(
    ProcurementProvider procurementProvider,
  )
  call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final procurementProvider = context.read<ProcurementProvider>();
  final navigator = Navigator.of(context);
  final result = await call(procurementProvider);
  if (!context.mounted) return result != null;
  if (result == null) {
    showMessage(context, procurementProvider.errorMessage ?? 'Could not save');
    return false;
  }
  final number = result['number'];
  showMessage(context, number == null ? done : '$done · $number');
  if (close) navigator.pop();
  return true;
}

/// Asks for one line of text; null when dismissed. [required] blocks an empty answer.
/// The dialog owns its controller so it outlives the closing animation.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String? initial,
  bool number = false,
  bool required = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _AskTextDialog(
    title: title,
    label: label,
    hint: hint,
    initial: initial,
    number: number,
    required: required,
  ),
);

class _AskTextDialog extends StatefulWidget {
  const _AskTextDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initial,
    required this.number,
    required this.required,
  });

  final String title;
  final String label;
  final String? hint;
  final String? initial;
  final bool number;
  final bool required;

  @override
  State<_AskTextDialog> createState() => _AskTextDialogState();
}

class _AskTextDialogState extends State<_AskTextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: widget.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (widget.required && value.isEmpty) return;
          Navigator.pop(context, value);
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}
