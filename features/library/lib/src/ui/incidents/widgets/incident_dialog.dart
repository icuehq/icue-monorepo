import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Details of a lost or damaged book incident, with a resolve action while it is open.
class IncidentDialog extends StatefulWidget {
  const IncidentDialog({super.key, required this.incident});

  final LibraryIncident incident;

  static Future<void> show(BuildContext context, LibraryIncident incident) =>
      showDialog<void>(
        context: context,
        builder: (_) => IncidentDialog(incident: incident),
      );

  @override
  State<IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<IncidentDialog> {
  bool _busy = false;

  Future<void> _resolve() async {
    final damaged = widget.incident.type == 'damaged';
    var resolution = damaged ? 'repaired' : 'replaced';
    final repairCostController = TextEditingController();
    final chargeController = TextEditingController();
    final remarksController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => IcueDialog(
          title: 'Resolve incident',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IcueDropdown<String>(
                value: resolution,
                items: [
                  if (damaged)
                    const DropdownMenuItem(
                      value: 'repaired',
                      child: Text('Repaired (return to shelf)'),
                    ),
                  const DropdownMenuItem(
                    value: 'replaced',
                    child: Text('Replaced'),
                  ),
                  const DropdownMenuItem(
                    value: 'written_off',
                    child: Text('Written off (withdraw copy)'),
                  ),
                  const DropdownMenuItem(
                    value: 'charged',
                    child: Text('Charged penalty'),
                  ),
                  const DropdownMenuItem(
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
          secondaryAction: IcueDialogAction(
            label: 'Cancel',
            variant: IcueButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          primaryAction: IcueDialogAction(
            label: 'Resolve',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final repairCost = double.tryParse(repairCostController.text.trim());
    final charge = double.tryParse(chargeController.text.trim());

    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = await libraryProvider.resolveIncident(
      id: widget.incident.id,
      resolution: resolution,
      repairCost: repairCost,
      charge: charge,
      remarks: blankToNull(remarksController),
    );
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: LibraryStatusChip(incident.status),
        ),
        const SizedBox(height: 12),
        if (incident.bookTitle != null) _Field('Book', incident.bookTitle!),
        _Field('Copy', incident.barcode),
        if (incident.severity != null)
          _Field('Severity', humanizeStatus(incident.severity)),
        if (incident.memberLabel != null)
          _Field('Member', incident.memberLabel!),
        if (incident.admissionNumber?.isNotEmpty ?? false)
          _Field('Admission no.', incident.admissionNumber!),
        if (incident.memberClassId != null)
          _Field(
            'Class',
            context.read<LibraryProvider>().classLabel(
              incident.memberClassId,
              incident.memberSection,
            ),
          ),
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
      ],
    );

    void close() => Navigator.of(context, rootNavigator: true).pop();
    final closeAction = IcueDialogAction(
      label: 'Close',
      variant: IcueButtonVariant.ghost,
      onPressed: close,
    );
    return IcueDialog(
      title: '${fineTypeLabel(incident.type)} incident',
      size: IcueDialogSize.large,
      content: content,
      secondaryAction: incident.isOpen ? closeAction : null,
      primaryAction: incident.isOpen
          ? IcueDialogAction(
              label: 'Resolve incident',
              isLoading: _busy,
              onPressed: _busy ? null : _resolve,
            )
          : closeAction,
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
