import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows the document number and (when [close]) leaves the sheet/page.
Future<bool> assetSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(AssetsProvider p) call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final p = context.read<AssetsProvider>();
  final nav = Navigator.of(context);
  final res = await call(p);
  if (!context.mounted) return res != null;
  if (res == null) {
    invSnack(context, p.errorMessage ?? 'Could not save');
    return false;
  }
  final number = res['number'];
  invSnack(context, number == null ? done : '$done · $number');
  if (close) nav.pop();
  return true;
}

/// Optional `yyyy-MM-dd` field with a picker; empty means none.
Widget optionalDate(
  BuildContext context,
  TextEditingController c,
  String label, {
  required DateTime first,
  required DateTime last,
}) => TextFormField(
  controller: c,
  readOnly: true,
  decoration: InputDecoration(
    labelText: label,
    suffixIcon: c.text.isEmpty
        ? const Icon(Icons.event_rounded)
        : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: c.clear),
  ),
  onTap: () async {
    final d = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: DateTime.now().isBefore(first) ? first : DateTime.now(),
    );
    if (d != null) c.text = d.toIso8601String().substring(0, 10);
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
    for (final v in values)
      DropdownMenuItem(value: v, child: Text((text ?? _title)(v))),
  ],
  onChanged: onChanged,
);

String _title(String s) =>
    s.replaceAll('_', ' ').replaceRange(0, 1, s.substring(0, 1).toUpperCase());

Color statusColor(String s) => switch (s) {
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
