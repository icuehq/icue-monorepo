import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Details collected for one vehicle document upload.
class VehicleDocUpload {
  const VehicleDocUpload({
    required this.number,
    required this.startDate,
    required this.expiryDate,
    required this.file,
  });

  final String number;
  final String startDate;
  final String expiryDate;
  final PickedFile file;
}

/// Collects number, dates and file for [docType] (all required, as before).
class VehicleDocUploadDialog extends StatefulWidget {
  const VehicleDocUploadDialog({super.key, required this.docType});

  final String docType;

  static Future<VehicleDocUpload?> show(BuildContext context, String docType) {
    return showDialog<VehicleDocUpload>(
      context: context,
      builder: (_) => VehicleDocUploadDialog(docType: docType),
    );
  }

  @override
  State<VehicleDocUploadDialog> createState() => _VehicleDocUploadDialogState();
}

class _VehicleDocUploadDialogState extends State<VehicleDocUploadDialog> {
  final _number = TextEditingController();
  DateTime? _start;
  DateTime? _expiry;
  PickedFile? _file;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial, {required bool future}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2000),
      lastDate: future ? DateTime(2100) : now,
    );
  }

  void _submit() {
    final file = _file;
    final start = _start;
    final expiry = _expiry;
    final label = widget.docType;
    final error = _number.text.trim().isEmpty
        ? '$label number is required'
        : start == null
        ? 'Start date is required'
        : expiry == null
        ? 'Expiry date is required'
        : file == null
        ? 'Choose a document'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      VehicleDocUpload(
        number: _number.text.trim(),
        startDate: start!.toUsDate(),
        expiryDate: expiry!.toUsDate(),
        file: file!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startLabel = widget.docType == 'Insurance'
        ? 'Insured date'
        : 'Start date';
    return AlertDialog(
      title: Text('Upload ${widget.docType}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _number,
              decoration: InputDecoration(
                labelText: '${widget.docType} number',
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: _start == null
                  ? startLabel
                  : '$startLabel: ${_start!.toNumericDate()}',
              onPressed: () async {
                final date = await _pickDate(_start, future: false);
                if (date != null) setState(() => _start = date);
              },
              variant: AppButtonVariant.outline,
            ),
            AppButton(
              label: _expiry == null
                  ? 'Expiry date'
                  : 'Expiry date: ${_expiry!.toNumericDate()}',
              onPressed: () async {
                final date = await _pickDate(_expiry, future: true);
                if (date != null) setState(() => _expiry = date);
              },
              variant: AppButtonVariant.outline,
            ),
            AppButton(
              label: _file?.name ?? 'Choose document',
              onPressed: () async {
                final picked = await pickFile(context, allowDocuments: true);
                if (picked == null) return;
                if (picked.isPdf && picked.bytes.length > 300000) {
                  setState(() => _error = 'File size should be under 300 KB');
                  return;
                }
                setState(() {
                  _file = picked;
                  _error = null;
                });
              },
              variant: AppButtonVariant.outline,
              leadingIcon: Icons.attach_file,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
          variant: AppButtonVariant.ghost,
        ),
        AppButton(label: 'Upload', onPressed: _submit),
      ],
    );
  }
}
