import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

/// Represents a single item line selected for a request.
class RequestItemLine {
  RequestItemLine({
    required this.item,
    this.variant,
    double initialQuantity = 1.0,
  }) : quantityController = TextEditingController(
         text: initialQuantity == initialQuantity.toInt()
             ? initialQuantity.toInt().toString()
             : initialQuantity.toString(),
       );

  final InventoryItem item;
  final InventoryVariant? variant;
  final TextEditingController quantityController;

  String get key => '${item.id}|${variant?.id}';

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0;

  void increment([double step = 1]) {
    final current = quantity;
    final updated = current + step;
    quantityController.text = updated == updated.toInt()
        ? updated.toInt().toString()
        : updated.toString();
  }

  void decrement([double step = 1]) {
    final current = quantity;
    if (current <= step) return;
    final updated = current - step;
    quantityController.text = updated == updated.toInt()
        ? updated.toInt().toString()
        : updated.toString();
  }

  /// Disposes after the closing sheet/row animation, which may still build the field.
  void disposeLater() =>
      Future<void>.delayed(const Duration(milliseconds: 500), dispose);

  void dispose() {
    quantityController.dispose();
  }
}
