import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Detailed view of a lost or damaged book incident with resolve action.
class IncidentDialog extends StatefulWidget {
  const IncidentDialog({super.key, required this.incident});

  final LibraryIncident incident;

  static Future<void> show(BuildContext context, LibraryIncident incident) =>
      showFormPage(context, () => IncidentDialog(incident: incident));

  @override
  State<IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<IncidentDialog> {
  bool _busy = false;

  Future<void> _resolve() async {
    String resolution = 'repaired';
    final repairCostController = TextEditingController();
    final chargeController = TextEditingController();
    final remarksController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resolve incident'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDropdown<String>(
                  value: resolution,
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
                  onChanged: (value) {
                    if (value != null) setDialogState(() => resolution = value);
                  },
                  label: 'Resolution',
                ),
                const SizedBox(height: 8),
                if (resolution == 'repaired')
                  AppTextField(
                    controller: repairCostController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label: 'Repair cost (₹)',
                    hintText: 'Optional',
                  ),
                if (widget.incident.memberId != null) ...[
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: chargeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label: 'Fine / penalty charge (₹)',
                    hintText: 'Optional additional penalty',
                  ),
                ],
                const SizedBox(height: 8),
                AppTextField(
                  controller: remarksController,
                  label: 'Resolution remarks',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final result = await libraryProvider.resolveIncident({
      'id': widget.incident.id,
      'resolution': resolution,
      'repairCost': ?repairCost,
      'charge': ?charge,
      'remarks': ?blankToNull(remarksController),
    });
    if (!mounted) return;
    if (result) {
      navigator.pop();
      showMessage(context, 'Incident resolved');
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Failed to resolve incident',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final libraryProvider = context.watch<LibraryProvider>();
    final canOperate = libraryProvider.access.can(
      'library.circulation.operate',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              incident.incidentNumber,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Chip(
              label: Text(humanizeStatus(incident.status)),
              backgroundColor: incident.isOpen
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Book copy: ${incident.accessionNumber} · Kind: ${humanizeStatus(incident.type)}',
        ),
        if (incident.severity != null)
          Text('Severity: ${humanizeStatus(incident.severity)}'),
        if (incident.memberLabel != null)
          Text('Member: ${incident.memberLabel}'),
        Text('Reported on: ${incident.reportedDate.toDisplayDay()}'),
        if (incident.description != null &&
            incident.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Description: ${incident.description}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (incident.charge > 0) Text('Charge: ${incident.charge.toRupees()}'),
        if (incident.repairCost != null)
          Text('Repair cost: ${incident.repairCost!.toRupees()}'),
        if (!incident.isOpen) ...[
          const Divider(height: 24),
          Text(
            'Resolution: ${incidentResolutionLabel(incident.resolution)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (incident.resolutionRemarks != null)
            Text('Remarks: ${incident.resolutionRemarks}'),
        ],
        if (incident.isOpen && canOperate) ...[
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
