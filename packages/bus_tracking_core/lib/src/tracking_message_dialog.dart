import 'dart:async';

import 'package:flutter/material.dart';

/// Tells why live tracking is not available (route not started or completed),
/// then calls [onClose] after [seconds], on Close, or on back.
///
/// Plain [AlertDialog] with English text on purpose, so the SDK and the parent
/// app show the same dialog. The caller owns navigation: [onClose] must pop the
/// dialog (and whatever else it wants to leave).
class TrackingMessageDialog extends StatefulWidget {
  const TrackingMessageDialog({
    required this.message,
    required this.onClose,
    this.seconds = 5,
    super.key,
  });

  final String message;
  final void Function(BuildContext context) onClose;
  final int seconds;

  @override
  State<TrackingMessageDialog> createState() => _TrackingMessageDialogState();
}

class _TrackingMessageDialogState extends State<TrackingMessageDialog> {
  late final Timer _timer;
  late int _left = widget.seconds;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // A Timer, not an AnimationController: animations disabled by the OS would
    // otherwise shrink the countdown to a fraction of a second.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _close();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _timer.cancel();
    widget.onClose(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: Text(
        widget.message,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      content: const SizedBox(width: 500),
      actions: [TextButton(onPressed: _close, child: Text('Close ($_left)'))],
    ),
  );
}
