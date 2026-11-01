import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Form to report a lost or damaged book copy (FRS 11.14).
class IncidentReportSheet extends StatefulWidget {
  const IncidentReportSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showFormSheet(context, () => const IncidentReportSheet());

  @override
  State<IncidentReportSheet> createState() => _IncidentReportSheetState();
}

class _IncidentReportSheetState extends State<IncidentReportSheet> {
  final _code = TextEditingController();
  final _erpId = TextEditingController();
  final _charge = TextEditingController();
  final _description = TextEditingController();

  String _kind = 'damaged';
  String _severity = 'moderate';
  String _memberType = 'student';
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
      _code.text = copy.accessionNumber;
    });
  }

  Future<void> _submit() async {
    if (_copy == null) {
      showMessage(context, 'Scan or enter a valid book copy accession number');
      return;
    }
    final personErpId = int.tryParse(_erpId.text.trim());
    final memberId = personErpId != null ? '${_memberType}_$personErpId' : null;
    final charge = double.tryParse(_charge.text.trim()) ?? 0;

    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ok = await libraryProvider.reportIncident({
      'copyId': _copy!.id,
      'memberId': ?memberId,
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
        ScanField(
          hint: 'Scan barcode or enter accession no.',
          onScan: _lookupCopy,
        ),
        if (_copy != null) ...[
          const SizedBox(height: 4),
          Text(
            'Selected copy: ${_copy!.accessionNumber} (${_copy!.status})',
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
          DropdownButtonFormField<String>(
            initialValue: _severity,
            decoration: const InputDecoration(labelText: 'Damage severity'),
            items: const [
              DropdownMenuItem(value: 'minor', child: Text('Minor')),
              DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
              DropdownMenuItem(value: 'severe', child: Text('Severe')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _severity = value);
            },
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'student', label: Text('Student')),
                ButtonSegment(value: 'teacher', label: Text('Teacher')),
              ],
              selected: {_memberType},
              onSelectionChanged: (values) =>
                  setState(() => _memberType = values.first),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _erpId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Member ERP ID (optional)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _charge,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Penalty / replacement charge (₹)',
            hintText: '0 if no fine',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          decoration: const InputDecoration(labelText: 'Description / remarks'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Submit report'),
        ),
      ],
    );
  }
}
