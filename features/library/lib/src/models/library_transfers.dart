import 'package:school_library/src/models/library_transfers.g.dart';

export 'library_transfers.g.dart';

String transferStatusLabel(String value) => switch (value) {
  'requested' => 'Requested',
  'approved' => 'Approved',
  'dispatched' => 'In transit',
  'partially_received' => 'Partly received',
  'received' => 'Received',
  'cancelled' => 'Cancelled',
  _ => value,
};

extension LibraryTransferMembers on LibraryTransfer {
  List<LibraryTransferLine> get pending => [
    for (final transferLine in lineItems)
      if (!transferLine.received) transferLine,
  ];
}
