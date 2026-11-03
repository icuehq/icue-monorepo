import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows the document number and (when [close]) leaves the screen.
/// No fixed request ID: each tap is its own action (a saved draft is later submitted).
Future<bool> procSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(
    ProcurementProvider procurementProvider,
  )
  call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final procurementProvider = context.read<ProcurementProvider>();
  final navigator = Navigator.of(context);
  final result = await call(procurementProvider);
  if (!context.mounted) return result != null;
  if (result == null) {
    showMessage(context, procurementProvider.errorMessage ?? 'Could not save');
    return false;
  }
  final number = result['number'];
  showMessage(context, number == null ? done : '$done · $number');
  if (close) navigator.pop();
  return true;
}
