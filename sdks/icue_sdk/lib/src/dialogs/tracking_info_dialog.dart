import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/material.dart';

/// Shows [message], then leaves live tracking: pops the dialog and the
/// tracking page back to the host app.
Future<void> showTrackingInfoDialog(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          TrackingMessageDialog(message: message, onClose: _popDialogAndPage),
    );

void _popDialogAndPage(BuildContext context) {
  var count = 0;
  Navigator.of(context).popUntil((route) => count++ >= 2 || route.isFirst);
}
