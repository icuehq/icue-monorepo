import 'package:inventory/src/services/adjustment_writes.dart';
import 'package:inventory/src/services/issue_writes.dart';
import 'package:inventory/src/services/receiving_writes.dart';
import 'package:inventory/src/services/return_writes.dart';

/// Client-side stock writes, routed to [ReceivingWrites], [IssueWrites], [ReturnWrites] and [AdjustmentWrites]: Receive Stock (`inventory-receipt-confirm`), receiving goods against a purchase order (`inventory-purchaseOrder-receive`), issue request submit/approve/reject, issuing stock (`inventory-issue-create`) confirming an issue's receipt returns against an issue requesting, stock adjustments and unavailable stock.
///
/// One Firestore transaction writes the receipt, its balances, the ledger rows
/// and the GRN counter (Receive Stock writes only the balances). Business checks live here and in `firestore.rules`
/// (`inventory.stock.operate`). Receipts, issues, returns, adjustments and
/// requests stamp `lastWrite`, which the audit triggers log. There is no
/// low-stock notification and no retry idempotency.
class StockWrites {
  static final _receiving = ReceivingWrites();
  static final _issues = IssueWrites();
  static final _returns = ReturnWrites();
  static final _adjustments = AdjustmentWrites();

  static final _handlers =
      <String, Future<Map<String, dynamic>> Function(Map<String, Object?>)>{
        'inventory-receipt-confirm': _receiving.confirmReceipt,
        'inventory-purchaseOrder-receive': _receiving.receivePurchaseOrder,
        'inventory-issueRequest-submit': _issues.submitIssueRequest,
        'inventory-issueRequest-decide': _issues.decideIssueRequest,
        'inventory-issueRequest-cancel': (data) =>
            _issues.endIssueRequest(data, cancel: true),
        'inventory-issueRequest-close': (data) =>
            _issues.endIssueRequest(data, cancel: false),
        'inventory-issue-create': _issues.issueStock,
        'inventory-issue-acknowledge': _issues.acknowledgeIssue,
        'inventory-return-create': _returns.createReturn,
        'inventory-adjustment-create': _adjustments.adjustStock,
        'inventory-unavailable-report': _adjustments.reportUnavailable,
        'inventory-unavailable-resolve': _adjustments.resolveUnavailable,
      };

  /// Action names `StockProvider.act` routes here instead of to a callable.
  static Iterable<String> get names => _handlers.keys;

  Future<Map<String, dynamic>> run(String name, Map<String, Object?> data) =>
      _handlers[name]?.call(data) ?? (throw ArgumentError.value(name, 'name'));
}
