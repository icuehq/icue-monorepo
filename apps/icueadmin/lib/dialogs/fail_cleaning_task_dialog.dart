import 'package:flutter/material.dart';

class FailCleaningTaskDialog extends StatefulWidget {
  const FailCleaningTaskDialog({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.onConfirm,
  });

  final int taskId;
  final String taskName;
  final Future<void> Function(String reason) onConfirm;

  @override
  State<FailCleaningTaskDialog> createState() => _FailCleaningTaskDialogState();
}

class _FailCleaningTaskDialogState extends State<FailCleaningTaskDialog> {
  final TextEditingController _remarksController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  final List<String> _commonFailReasons = [
    'Water supply unavailable',
    'Cleaning equipment / chemicals unavailable',
    'Hazardous spill requiring specialized team',
    'Structural damage / unsafe environment',
    'Power outage in facility area',
  ];

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(_remarksController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Report Task Failure',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task: ${widget.taskName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please explain why this cleaning task could not be completed:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _commonFailReasons.map((reason) {
                    return ActionChip(
                      label: Text(reason, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _remarksController.text = reason;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter specific failure reason...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Failure reason is required';
                    }
                    if (value.trim().length < 5) {
                      return 'Please provide a more descriptive reason';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: Size.zero),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            backgroundColor: theme.colorScheme.error,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _submitting ? null : _handleSubmit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Mark as Failed'),
        ),
      ],
    );
  }
}
