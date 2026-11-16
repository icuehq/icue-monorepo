import 'package:inventory/src/services/adjustment_writes.dart';
import 'package:inventory/src/services/issue_writes.dart';
import 'package:inventory/src/services/receiving_writes.dart';
import 'package:inventory/src/services/return_writes.dart';

/// Client-side stock writes, routed to [ReceivingWrites], [IssueWrites], [ReturnWrites] and [AdjustmentWrites]: Receive Stock (`inventory-receipt-confirm`), receiving goods against a purchase order (`inventory-purchaseOrder-receive`), issue request approve/reject, issuing stock (`inventory-issue-create`) confirming an issue's receipt returns against an issue requesting, stock adjustments and unavailable stock.
///
/// One Firestore transaction writes the receipt, its balances, the ledger rows
/// and the GRN counter (Receive Stock writes only the balances). Business checks live here and in `firestore.rules`
/// (`inventory.stock.operate`). Receipts, issues, returns, adjustments and
/// requests stamp `lastWrite`, which the audit triggers log. There is no
/// low-stock notification and no retry idempotency.
class StockWrites {
  /// Action names `StockProvider.act` routes here instead of to a callable.
  static const names = {
    'inventory-receipt-confirm',
    'inventory-purchaseOrder-receive',
    'inventory-issueRequest-decide',
    'inventory-issueRequest-cancel',
    'inventory-issueRequest-close',
    'inventory-issue-create',
    'inventory-issue-acknowledge',
    'inventory-return-create',
    'inventory-adjustment-create',
    'inventory-unavailable-report',
    'inventory-unavailable-resolve',
  };

  final _receiving = ReceivingWrites();
  final _issues = IssueWrites();
  final _returns = ReturnWrites();
  final _adjustments = AdjustmentWrites();

  Future<Map<String, dynamic>> run(
    String name,
    Map<String, Object?> data,
  ) => switch (name) {
    'inventory-receipt-confirm' => _receiving.confirmReceipt(data),
    'inventory-purchaseOrder-receive' => _receiving.receivePurchaseOrder(data),
    'inventory-issueRequest-decide' => _issues.decideIssueRequest(data),
    'inventory-issueRequest-cancel' => _issues.endIssueRequest(
      data,
      cancel: true,
    ),
    'inventory-issueRequest-close' => _issues.endIssueRequest(
      data,
      cancel: false,
    ),
    'inventory-issue-create' => _issues.issueStock(data),
    'inventory-issue-acknowledge' => _issues.acknowledgeIssue(data),
    'inventory-return-create' => _returns.createReturn(data),
    'inventory-adjustment-create' => _adjustments.adjustStock(data),
    'inventory-unavailable-report' => _adjustments.reportUnavailable(data),
    'inventory-unavailable-resolve' => _adjustments.resolveUnavailable(data),
    _ => throw ArgumentError.value(name, 'name'),
  };
}
