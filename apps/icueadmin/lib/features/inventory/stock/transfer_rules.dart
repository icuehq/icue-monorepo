import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';

bool _onCampus(ModuleAccess access, int campusId) =>
    access.hasAllCampuses || access.campusIds.contains(campusId);

/// Dispatch happens at the source store's campus.
bool canDispatchTransfer(InventoryTransfer transfer, ModuleAccess access) =>
    transfer.status == 'requested' &&
    access.can('inventory.stock.operate') &&
    _onCampus(access, transfer.fromCampusId);

/// Receipt happens at the destination store's campus.
bool canReceiveTransfer(InventoryTransfer transfer, ModuleAccess access) =>
    transfer.inTransit &&
    access.can('inventory.stock.operate') &&
    _onCampus(access, transfer.toCampusId);

/// What this user should do next on [transfer], or null when nothing waits on them.
String? transferNextAction(InventoryTransfer transfer, ModuleAccess access) {
  if (canDispatchTransfer(transfer, access)) return 'Ready to dispatch';
  if (canReceiveTransfer(transfer, access)) return 'Confirm receipt on arrival';
  return null;
}

/// What the transfer waits for, shown to users who cannot act on it.
String transferWaitingFor(InventoryTransfer transfer) =>
    switch (transfer.status) {
      'requested' => 'Waiting for the source store to dispatch the stock.',
      'dispatched' || 'partially_received' =>
        'Waiting for the destination store to confirm receipt.',
      _ => '',
    };

Color transferStatusColor(String status) => switch (status) {
  'dispatched' => Colors.blue.shade800,
  'partially_received' => Colors.purple.shade800,
  'received' => Colors.green.shade800,
  _ => Colors.amber.shade900,
};
