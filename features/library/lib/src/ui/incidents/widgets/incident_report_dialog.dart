import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Form to report a lost or damaged book copy (FRS 11.14).
class IncidentReportDialog extends StatefulWidget {
  const IncidentReportDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showFormPage(context, () => const IncidentReportDialog());

  @override
  State<IncidentReportDialog> createState() => _IncidentReportDialogState();
}

class _IncidentReportDialogState extends State<IncidentReportDialog> {
  final _code = TextEditingController();
  final _erpId = TextEditingController();
  final _charge = TextEditingController();
  final _description = TextEditingController();

  String _kind = 'damaged';
  String _severity = 'moderate';
  LibraryCopy? _copy;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _erpId.dispose();
    _charge.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _lookupCopy(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    if (copy == null) {
      showMessage(context, 'No copy found for "$code"');
      return;
    }
    setState(() {
      _copy = copy;
      _code.text = copy.barcode;
    });
  }

  Future<void> _submit() async {
    if (_copy == null) {
      showMessage(context, 'Scan or enter a valid book copy barcode');
      return;
    }
    final personErpId = int.tryParse(_erpId.text.trim());
    final charge = double.tryParse(_charge.text.trim()) ?? 0;

    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ok = await libraryProvider.reportIncident({
      'barcode': _copy!.id,
      'personErpId': ?personErpId,
      'type': _kind,
      'severity': _kind == 'damaged' ? _severity : 'moderate',
      'description': ?blankToNull(_description),
      'charge': charge,
    });
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      showMessage(context, 'Incident reported successfully');
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Failed to report incident',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Report Lost / Damaged Book',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        IcueScanField(
          hint: 'Scan or enter the copy barcode',
          onScan: _lookupCopy,
        ),
        if (_copy != null) ...[
          const SizedBox(height: 4),
          Text(
            'Selected copy: ${_copy!.barcode} (${_copy!.status})',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'damaged', label: Text('Damaged')),
            ButtonSegment(value: 'lost', label: Text('Lost')),
          ],
          selected: {_kind},
          onSelectionChanged: (values) => setState(() => _kind = values.first),
        ),
        if (_kind == 'damaged') ...[
          const SizedBox(height: 12),
          IcueDropdown<String>(
            value: _severity,
            items: const [
              DropdownMenuItem(value: 'minor', child: Text('Minor')),
              DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
              DropdownMenuItem(value: 'severe', child: Text('Severe')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _severity = value);
            },
            label: 'Damage severity',
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _erpId,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Member ERP ID (optional)',
          ),
        ),
        const SizedBox(height: 8),
        IcueTextField(
          controller: _charge,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          label: 'Penalty / replacement charge (₹)',
          hintText: '0 if no fine',
        ),
        const SizedBox(height: 8),
        IcueTextField(controller: _description, label: 'Description / remarks'),
        const SizedBox(height: 16),
        IcueButton(label: 'Submit report', onPressed: _busy ? null : _submit),
      ],
    );
  }
}
