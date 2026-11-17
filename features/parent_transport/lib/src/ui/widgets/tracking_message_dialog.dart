import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';

/// Tells why tracking is not available, then sends the parent home after 5 s.
class TrackingMessageDialog extends StatefulWidget {
  const TrackingMessageDialog({required this.message, super.key});

  final String message;

  @override
  State<TrackingMessageDialog> createState() => _TrackingMessageDialogState();
}

class _TrackingMessageDialogState extends State<TrackingMessageDialog> {
  static const _seconds = 5;

  late final Timer _timer;
  int _left = _seconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_left <= 1) {
        _goHome();
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

  void _goHome() {
    _timer.cancel();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _goHome();
    },
    child: IcueDialog(
      title: widget.message,
      size: IcueDialogSize.small,
      primaryAction: IcueDialogAction(
        label: '${ParentLocalizations.of(context).close} ($_left)',
        onPressed: _goHome,
      ),
    ),
  );
}
