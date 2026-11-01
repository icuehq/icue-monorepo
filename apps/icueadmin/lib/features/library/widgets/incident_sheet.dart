import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Detailed view of a lost or damaged book incident with resolve action.
class IncidentSheet extends StatefulWidget {
  const IncidentSheet({super.key, required this.incident});

  final LibIncident incident;

  static Future<void> show(BuildContext context, LibIncident incident) =>
      showInvSheet(context, () => IncidentSheet(incident: incident));

  @override
  State<IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<IncidentSheet> {
  bool _busy = false;

  Future<void> _resolve() async {
    String resolution = 'repaired';
    final repairCostController = TextEditingController();
    final chargeController = TextEditingController();
    final remarksController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Resolve incident'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: resolution,
                  decoration: const InputDecoration(labelText: 'Resolution'),
                  items: const [
                    DropdownMenuItem(
                      value: 'repaired',
                      child: Text('Repaired (return to shelf)'),
                    ),
                    DropdownMenuItem(
                      value: 'replaced',
                      child: Text('Replaced'),
                    ),
                    DropdownMenuItem(
                      value: 'written_off',
                      child: Text('Written off (withdraw copy)'),
                    ),
                    DropdownMenuItem(
                      value: 'charged',
                      child: Text('Charged penalty'),
                    ),
                    DropdownMenuItem(
                      value: 'dismissed',
                      child: Text('Dismissed'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => resolution = v);
                  },
                ),
                const SizedBox(height: 8),
                if (resolution == 'repaired')
                  TextField(
                    controller: repairCostController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Repair cost (₹)',
                      hintText: 'Optional',
                    ),
                  ),
                if (widget.incident.memberId != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: chargeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Fine / penalty charge (₹)',
                      hintText: 'Optional additional penalty',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Resolution remarks',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final repairCost = double.tryParse(repairCostController.text.trim());
    final charge = double.tryParse(chargeController.text.trim());

    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final res = await p.resolveIncident({
      'id': widget.incident.id,
      'resolution': resolution,
      'repairCost': ?repairCost,
      'charge': ?charge,
      'remarks': ?blankToNull(remarksController),
    });
    if (!mounted) return;
    if (res) {
      nav.pop();
      invSnack(context, 'Incident resolved');
    } else {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Failed to resolve incident');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inc = widget.incident;
    final p = context.watch<LibraryProvider>();
    final canOperate = p.access.can('lib.circulation.operate');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              inc.incidentNumber,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Chip(
              label: Text(incidentStatusLabel(inc.status)),
              backgroundColor: inc.isOpen
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Book copy: ${inc.accessionNo} · Kind: ${incidentKindLabel(inc.kind)}',
        ),
        if (inc.severity != null)
          Text('Severity: ${incidentSeverityLabel(inc.severity)}'),
        if (inc.memberLabel != null) Text('Member: ${inc.memberLabel}'),
        Text('Reported on: ${inc.reportedDate}'),
        if (inc.description != null && inc.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Description: ${inc.description}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (inc.charge > 0) Text('Charge: ₹${inc.charge.toStringAsFixed(2)}'),
        if (inc.repairCost != null)
          Text('Repair cost: ₹${inc.repairCost!.toStringAsFixed(2)}'),
        if (!inc.isOpen) ...[
          const Divider(height: 24),
          Text(
            'Resolution: ${incidentResolutionLabel(inc.resolution)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (inc.resolutionRemarks != null)
            Text('Remarks: ${inc.resolutionRemarks}'),
        ],
        if (inc.isOpen && canOperate) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _resolve,
            child: const Text('Resolve incident'),
          ),
        ],
      ],
    );
  }
}
