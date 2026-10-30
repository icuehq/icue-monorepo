import 'package:flutter/material.dart';
import 'package:logbook/logbook.dart';

class UpdateComplaintModal extends StatefulWidget {
  const UpdateComplaintModal({
    super.key,
    required this.complaint,
    required this.onSubmit,
  });

  final Complaint complaint;
  final Future<void> Function(UpdateComplaintRequest request) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required Complaint complaint,
    required Future<void> Function(UpdateComplaintRequest request) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => UpdateComplaintModal(
        complaint: complaint,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<UpdateComplaintModal> createState() => _UpdateComplaintModalState();
}

class _UpdateComplaintModalState extends State<UpdateComplaintModal> {
  final _formKey = GlobalKey<FormState>();
  late String _status;
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _photoName;
  List<int>? _photoBytes;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.complaint.currStatus == 'Open'
        ? 'In-Progress'
        : widget.complaint.currStatus;
  }

  @override
  void dispose() {
    _actionController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final req = UpdateComplaintRequest(
        id: widget.complaint.id,
        status: _status,
        action: _actionController.text.trim(),
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        photoBytes: _photoBytes,
        photoName: _photoName,
      );

      await widget.onSubmit(req);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update Complaint #${widget.complaint.complaintNo}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'In-Progress', child: Text('In-Progress')),
                  DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'Open', child: Text('Open')),
                ],
                onChanged: (val) => setState(() => _status = val ?? 'In-Progress'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _actionController,
                decoration: const InputDecoration(
                  labelText: 'Action Taken *',
                  hintText: 'e.g., Sent for inspection, Replaced part',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Resolution Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      _photoName != null
                          ? Icons.image_rounded
                          : Icons.add_a_photo_outlined,
                      color: _photoName != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _photoName ?? 'Resolution proof photo (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: _photoName != null
                              ? Colors.black
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (_photoName != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _photoName = null;
                            _photoBytes = null;
                          });
                        },
                      )
                    else
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _photoName = 'resolution_proof.jpg';
                            _photoBytes = [10, 20, 30];
                          });
                        },
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: const Text('Attach'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _isSubmitting ? null : _handleSave,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Update Complaint Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
