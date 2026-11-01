import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Runs [call]; on success shows the document number and (when [close]) leaves the screen.
/// No fixed request ID: each tap is its own action (a saved draft is later submitted).
Future<bool> procSubmit(
  BuildContext context,
  Future<Map<String, dynamic>?> Function(ProcurementProvider p) call, {
  bool close = true,
  String done = 'Saved',
}) async {
  final p = context.read<ProcurementProvider>();
  final nav = Navigator.of(context);
  final res = await call(p);
  if (!context.mounted) return res != null;
  if (res == null) {
    invSnack(context, p.errorMessage ?? 'Could not save');
    return false;
  }
  invSnack(context, '$done · ${res['number']}');
  if (close) nav.pop();
  return true;
}
