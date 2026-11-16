import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Details of a lost or damaged book incident, with a resolve action while it is open.
class IncidentDialog extends StatefulWidget {
  const IncidentDialog({super.key, required this.incident});

  final LibraryIncident incident;

  @override
  State<IncidentDialog> createState() => _IncidentDialogState();

  static Future<void> show(BuildContext context, LibraryIncident incident) =>
      showDialog<void>(
        context: context,
        builder: (_) => IncidentDialog(incident: incident),
      );
}

class _IncidentDialogState extends State<IncidentDialog> {
  bool _busy = false;

  Future<void> _resolve() async {
    final incident = widget.incident;
    final damaged = incident.type == 'damaged';
    var resolution = damaged ? 'repaired' : 'found';
    final repairCostController = TextEditingController();
    final chargeController = TextEditingController(
      text: incident.charge > 0 ? incident.charge.toString() : '',
    );
    final remarksController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => IcueDialog(
          title: 'Close this case',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IcueDropdown<String>(
                value: resolution,
                items: [
                  for (final option in _options(damaged))
                    DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => resolution = value);
                },
                label: 'What happened?',
              ),
              const SizedBox(height: 4),
              Text(
                _options(damaged)
                    .firstWhere((option) => option.value == resolution)
                    .hint,
                style: Theme.of(context).textTheme.bodySmall,
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
              if (damaged && incident.personErpId != null) ...[
                const SizedBox(height: 8),
                IcueTextField(
                  controller: chargeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  label: 'Total charge to member (₹)',
                  hintText: 'Raise to fine the difference',
                ),
              ],
              const SizedBox(height: 8),
              IcueTextField(
                controller: remarksController,
                label: 'Note (optional)',
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
    final charge = damaged
        ? double.tryParse(chargeController.text.trim())
        : null;

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
      IcueToast.success(context, 'Case closed');
    } else {
      setState(() => _busy = false);
      IcueToast.error(
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
        if (incident.type == 'lost' && incident.loanId != null)
          _LostFine(incident.loanId!),
        if (incident.repairCost != null)
          _Field('Repair cost', incident.repairCost!.toRupees()),
        if (!incident.isOpen) ...[
          const Divider(height: 24),
          _Field('Outcome', incidentResolutionLabel(incident.resolution)),
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
              label: 'Close case',
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

/// Status of the replacement fine raised when the loan was marked lost.
class _LostFine extends StatelessWidget {
  const _LostFine(this.loanId);

  final String loanId;

  @override
  Widget build(BuildContext context) => FutureBuilder<LibraryFine?>(
    future: context.read<LibraryProvider>().service.fine('${loanId}__lost'),
    builder: (context, snapshot) {
      final fine = snapshot.data;
      if (fine == null) return const SizedBox.shrink();
      return _Field(
        'Fine',
        '${fine.amount.toRupees()} (${humanizeStatus(fine.status)}'
            '${fine.outstanding > 0 ? ', ${fine.outstanding.toRupees()} due' : ''})',
      );
    },
  );
}

typedef _Option = ({String value, String label, String hint});

List<_Option> _options(bool damaged) => damaged
    ? const [
        (
          value: 'repaired',
          label: 'Book was repaired',
          hint: 'The book goes back on the shelf.',
        ),
        (
          value: 'written_off',
          label: 'Book cannot be repaired',
          hint: 'The book is removed from the library.',
        ),
        (
          value: 'no_damage',
          label: 'Book is actually fine',
          hint: 'The book goes back on the shelf.',
        ),
      ]
    : const [
        (
          value: 'found',
          label: 'Book was found',
          hint: 'The book goes back on the shelf and the fine is cancelled.',
        ),
        (
          value: 'replaced',
          label: 'Member gave a new book',
          hint: 'The lost book is removed and the fine is cancelled.',
        ),
        (
          value: 'not_recovered',
          label: 'Book is lost for good',
          hint: 'The lost book is removed and the member still has to pay the fine.',
        ),
      ];
