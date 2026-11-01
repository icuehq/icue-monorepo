import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Form to report a lost or damaged book copy (FRS 11.14).
class IncidentReportSheet extends StatefulWidget {
  const IncidentReportSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showInvSheet(context, () => const IncidentReportSheet());

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
  LibCopy? _copy;
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
    final p = context.read<LibraryProvider>();
    final c = await p.findCopy(code);
    if (!mounted) return;
    if (c == null) {
      invSnack(context, 'No copy found for "$code"');
      return;
    }
    setState(() {
      _copy = c;
      _code.text = c.accessionNo;
    });
  }

  Future<void> _submit() async {
    if (_copy == null) {
      invSnack(context, 'Scan or enter a valid book copy accession number');
      return;
    }
    final erp = int.tryParse(_erpId.text.trim());
    final memberId = erp != null ? '${_memberType}_$erp' : null;
    final charge = double.tryParse(_charge.text.trim()) ?? 0;

    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final ok = await p.reportIncident({
      'copyId': _copy!.id,
      'memberId': ?memberId,
      'kind': _kind,
      'severity': _kind == 'damaged' ? _severity : 'moderate',
      'description': ?blankToNull(_description),
      'charge': charge,
    });
    if (!mounted) return;
    if (ok) {
      nav.pop();
      invSnack(context, 'Incident reported successfully');
    } else {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Failed to report incident');
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
            'Selected copy: ${_copy!.accessionNo} (${_copy!.status})',
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
          onSelectionChanged: (s) => setState(() => _kind = s.first),
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
            onChanged: (v) {
              if (v != null) setState(() => _severity = v);
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
              onSelectionChanged: (s) => setState(() => _memberType = s.first),
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
