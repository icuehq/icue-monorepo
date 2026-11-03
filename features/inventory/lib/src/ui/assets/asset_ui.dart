import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows the document number and (when [close]) leaves the sheet/page.
Future<bool> assetSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(AssetsProvider assetsProvider) call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final assetsProvider = context.read<AssetsProvider>();
  final navigator = Navigator.of(context);
  final result = await call(assetsProvider);
  if (!context.mounted) return result != null;
  if (result == null) {
    showMessage(context, assetsProvider.errorMessage ?? 'Could not save');
    return false;
  }
  final number = result['number'];
  showMessage(context, number == null ? done : '$done · $number');
  if (close) navigator.pop();
  return true;
}

/// Optional `yyyy-MM-dd` field with a picker; empty means none.
Widget optionalDate(
  BuildContext context,
  TextEditingController controller,
  String label, {
  required DateTime first,
  required DateTime last,
}) => TextFormField(
  controller: controller,
  readOnly: true,
  decoration: InputDecoration(
    labelText: label,
    suffixIcon: controller.text.isEmpty
        ? const Icon(Icons.event_rounded)
        : IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: controller.clear,
          ),
  ),
  onTap: () async {
    final date = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: DateTime.now().isBefore(first) ? first : DateTime.now(),
    );
    if (date != null) controller.text = date.toIso8601String().substring(0, 10);
  },
);

DropdownButtonFormField<String> labelled(
  String label,
  List<String> values,
  String? value,
  ValueChanged<String?> onChanged, {
  String Function(String)? text,
}) => DropdownButtonFormField<String>(
  initialValue: value,
  decoration: InputDecoration(labelText: label),
  items: [
    for (final value in values)
      DropdownMenuItem(value: value, child: Text((text ?? _title)(value))),
  ],
  onChanged: onChanged,
);

String _title(String value) => value
    .replaceAll('_', ' ')
    .replaceRange(0, 1, value.substring(0, 1).toUpperCase());

Color statusColor(String value) => switch (value) {
  'available' || 'completed' => Colors.green,
  'assigned' || 'in_progress' => Colors.blue,
  'under_maintenance' || 'under_repair' || 'waiting_for_parts' => Colors.orange,
  'lost' || 'damaged' || 'urgent' => Colors.red,
  _ => Colors.grey,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(_title(status)),
    visualDensity: VisualDensity.compact,
    side: BorderSide(color: statusColor(status)),
    backgroundColor: statusColor(status).withValues(alpha: 0.12),
  );
}
