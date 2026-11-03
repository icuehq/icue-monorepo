import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

Color transferStatusColor(String status) => switch (status) {
  'approved' => Colors.blue.shade700,
  'dispatched' => Colors.purple.shade700,
  'partially_received' => Colors.deepOrange.shade700,
  'received' => Colors.green.shade700,
  _ => Colors.orange.shade800,
};

bool onCampus(ModuleAccess access, int campusId) =>
    access.hasAllCampuses || access.campusIds.contains(campusId);

bool canApproveTransfer(LibraryTransfer transfer, ModuleAccess access) =>
    transfer.status == 'requested' &&
    access.can('library.settings') &&
    onCampus(access, transfer.campusId);

bool canDispatchTransfer(LibraryTransfer transfer, ModuleAccess access) =>
    transfer.status == 'approved' &&
    access.can('library.catalogue.manage') &&
    onCampus(access, transfer.campusId);

bool isReceivable(LibraryTransfer transfer) =>
    transfer.status == 'dispatched' || transfer.status == 'partially_received';

bool canReceiveTransfer(LibraryTransfer transfer, ModuleAccess access) =>
    isReceivable(transfer) &&
    access.can('library.catalogue.manage') &&
    onCampus(access, transfer.toCampusId);

/// What this user should do next on [transfer], or null when nothing is waiting on them.
String? transferNextAction(LibraryTransfer transfer, ModuleAccess access) {
  if (canApproveTransfer(transfer, access)) return 'Needs your approval';
  if (canDispatchTransfer(transfer, access)) return 'Ready to dispatch';
  if (canReceiveTransfer(transfer, access)) return 'Confirm receipt on arrival';
  return null;
}

/// What the whole transfer is waiting for, for users who cannot act on it.
String transferWaitingFor(LibraryTransfer transfer) =>
    switch (transfer.status) {
      'requested' => 'Waiting for approval by a library administrator.',
      'approved' => 'Waiting for the source library to dispatch the copies.',
      'dispatched' || 'partially_received' =>
        'Waiting for the destination library to confirm receipt.',
      _ => '',
    };

class TransferStatusPill extends StatelessWidget {
  const TransferStatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = transferStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        transferStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
