import 'package:flutter/material.dart';

class SkipCleaningTaskDialog extends StatefulWidget {
  const SkipCleaningTaskDialog({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.onConfirm,
  });

  final int taskId;
  final String taskName;
  final Future<void> Function(String reason) onConfirm;

  @override
  State<SkipCleaningTaskDialog> createState() => _SkipCleaningTaskDialogState();
}

class _SkipCleaningTaskDialogState extends State<SkipCleaningTaskDialog> {
  final TextEditingController _remarksController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  final List<String> _commonReasons = [
    'Facility closed for maintenance',
    'Facility currently occupied',
    'Restricted access / locked',
    'Cleaner reassigned to higher priority area',
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
          Icon(Icons.skip_next, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Skip Cleaning Task',
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
                  'Please provide a mandatory reason for skipping this task:',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _commonReasons.map((reason) {
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
                    hintText: 'Enter reason / remarks here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Reason is required to skip task';
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
            backgroundColor: const Color(0xFFEA580C),
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
              : const Text('Confirm Skip'),
        ),
      ],
    );
  }
}
