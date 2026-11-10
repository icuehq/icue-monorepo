import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
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
                IcueDropdown<String>(
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
                  IcueTextField(
                    controller: repairCostController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label: 'Repair cost (₹)',
                    hintText: 'Optional',
                  ),
                if (widget.incident.personErpId != null) ...[
                  const SizedBox(height: 8),
                  IcueTextField(
                    controller: chargeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label: 'Fine / penalty charge (₹)',
                    hintText: 'Optional additional penalty',
                  ),
                ],
                const SizedBox(height: 8),
                IcueTextField(
                  controller: remarksController,
                  label: 'Resolution remarks',
                ),
              ],
            ),
          ),
          actions: [
            IcueButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(false),
              variant: IcueButtonVariant.ghost,
            ),
            IcueButton(
              label: 'Resolve',
              onPressed: () => Navigator.of(context).pop(true),
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
    final theme = Theme.of(context);
    final statusColor = incident.isOpen
        ? theme.colorScheme.error
        : Colors.green.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                incident.incidentNumber,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                humanizeStatus(incident.status),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Field('Book copy', incident.barcode),
        _Field('Kind', humanizeStatus(incident.type)),
        if (incident.severity != null)
          _Field('Severity', humanizeStatus(incident.severity)),
        if (incident.memberLabel != null)
          _Field('Member', incident.memberLabel!),
        _Field('Reported on', incident.reportedDate.toDisplayDay()),
        if (incident.description != null && incident.description!.isNotEmpty)
          _Field('Description', incident.description!),
        if (incident.charge > 0) _Field('Charge', incident.charge.toRupees()),
        if (incident.repairCost != null)
          _Field('Repair cost', incident.repairCost!.toRupees()),
        if (!incident.isOpen) ...[
          const Divider(height: 24),
          _Field('Resolution', incidentResolutionLabel(incident.resolution)),
          if (incident.resolutionRemarks != null)
            _Field('Remarks', incident.resolutionRemarks!),
        ],
        if (incident.isOpen) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: IcueButton(
              label: 'Resolve incident',
              onPressed: _busy ? null : _resolve,
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
