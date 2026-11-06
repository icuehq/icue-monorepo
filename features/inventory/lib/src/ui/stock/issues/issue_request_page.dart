import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issuance_card.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_request_widgets.dart';
import 'package:inventory/src/ui/stock/issues/widgets/issue_stock_card.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// One issue request (FRS 10.8): approve / reject, issue, confirm receipt and return, all on one screen.
class IssueRequestPage extends StatefulWidget {
  const IssueRequestPage({required this.requestId, super.key});

  final String requestId;

  @override
  State<IssueRequestPage> createState() => _IssueRequestPageState();
}

class _IssueRequestPageState extends State<IssueRequestPage> {
  InventoryIssueRequest? _request;
  var _issues = <InventoryIssue>[];
  var _loading = true;
  var _busy = false;
  String? _loadError;

  var _approved = <TextEditingController>[];
  var _issueNow = <TextEditingController>[];
  var _recipientType = 'staff';
  int? _recipientId;
  var _issueKey = newRequestId();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in [..._approved, ..._issueNow]) {
      controller.dispose();
    }
  }

  Future<void> _load() async {
    final stockProvider = context.read<StockProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    final request = await stockProvider.loadRequest(widget.requestId);
    if (!mounted) return;
    if (request == null) {
      return setState(() {
        _loading = false;
        _loadError = stockProvider.errorMessage ?? 'Request not found';
      });
    }
    final showIssues =
        !request.isPending &&
        request.status != 'rejected' &&
        inventoryProvider.access.can('inventory.stock.operate');
    final issues = showIssues
        ? await stockProvider.issuesOf(request)
        : <InventoryIssue>[];
    if (!mounted) return;
    final replaced = [..._approved, ..._issueNow];
    setState(() {
      _request = request;
      _issues = issues;
      _loading = false;
      _loadError = null;
      _approved = [
        for (final line in request.lineItems)
          TextEditingController(text: line.requested.toQuantityText()),
      ];
      _issueNow = [
        for (final line in request.lineItems)
          TextEditingController(
            text: (((line.approved ?? 0) - line.issued).clamp(
              0,
              double.infinity,
            )).toQuantityText(),
          ),
      ];
      _recipientId ??= int.tryParse(request.createdBy);
    });
    // Disposed after the rebuild, so no field still points at them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in replaced) {
        controller.dispose();
      }
    });
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? -1;

  /// Runs [action]; on success reloads the request so every section shows the new state.
  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final succeeded = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (succeeded) await _load();
  }

  Future<void> _approve(InventoryIssueRequest request) async {
    var total = 0.0;
    for (final (index, line) in request.lineItems.indexed) {
      final quantity = _number(_approved[index]);
      final name = context.read<StockProvider>().itemName(line.itemId);
      if (quantity < 0) {
        return showMessage(context, 'Enter a quantity for $name');
      }
      if (quantity > line.requested) {
        return showMessage(
          context,
          '$name: cannot approve more than the requested '
          '${line.requested.toQuantityText()}',
        );
      }
      total += quantity;
    }
    if (total <= 0) {
      return showMessage(
        context,
        'Nothing approved. Reject the request instead.',
      );
    }
    await _run(
      () => stockSubmit(
        context,
        (stockProvider) => stockProvider.act('inventory-issueRequest-decide', {
          'id': request.id,
          'decision': 'approve',
          'lineItems': [
            for (final (index, _) in request.lineItems.indexed)
              {'index': index, 'quantityApproved': _number(_approved[index])},
          ],
        }),
        close: false,
        done: 'Request approved',
      ),
    );
  }

  Future<void> _reject(InventoryIssueRequest request) async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;
    await _run(
      () => stockSubmit(
        context,
        (stockProvider) => stockProvider.act('inventory-issueRequest-decide', {
          'id': request.id,
          'decision': 'reject',
          'comment': reason,
        }),
        close: false,
        done: 'Request rejected',
      ),
    );
  }

  Future<String?> _askReason({
    String title = 'Reject request',
    String action = 'Reject',
  }) => showDialog<String>(
    context: context,
    builder: (context) {
      final reason = TextEditingController();
      String? error;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: reason,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Reason',
              hintText: 'Tell the requester why',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                if (reason.text.trim().isEmpty) {
                  return setDialogState(() => error = 'A reason is required');
                }
                Navigator.pop(context, reason.text.trim());
              },
              child: Text(action),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _end(
    InventoryIssueRequest request, {
    required bool cancel,
  }) async {
    final reason = await _askReason(
      title: cancel ? 'Cancel request' : 'Close request',
      action: cancel ? 'Cancel request' : 'Close request',
    );
    if (reason == null || !mounted) return;
    await _run(
      () => stockSubmit(
        context,
        (stockProvider) => stockProvider.act(
          cancel
              ? 'inventory-issueRequest-cancel'
              : 'inventory-issueRequest-close',
          {'id': request.id, 'reason': reason},
        ),
        close: false,
        done: cancel ? 'Request cancelled' : 'Request closed',
      ),
    );
  }

  Future<void> _issue(InventoryIssueRequest request) async {
    final recipientId = _recipientId;
    if (recipientId == null) {
      return showMessage(context, 'Choose who receives the items');
    }
    final lineItems = <Map<String, Object?>>[];
    for (final (index, line) in request.lineItems.indexed) {
      final remaining = (line.approved ?? 0) - line.issued;
      if (remaining <= 0) continue;
      final quantity = _number(_issueNow[index]);
      if (quantity < 0 || quantity > remaining) {
        final name = context.read<StockProvider>().itemName(line.itemId);
        return showMessage(
          context,
          '$name: enter 0 to ${remaining.toQuantityText()}',
        );
      }
      if (quantity > 0) {
        lineItems.add({
          'itemId': line.itemId,
          'variantId': ?line.variantId,
          'quantity': quantity,
        });
      }
    }
    if (lineItems.isEmpty) {
      return showMessage(context, 'Enter a quantity to issue');
    }
    await _run(() async {
      final succeeded = await stockSubmit(
        context,
        (stockProvider) => stockProvider.act('inventory-issue-create', {
          'issueRequestId': request.id,
          'recipient': {'type': _recipientType, 'personErpId': recipientId},
          'lineItems': lineItems,
        }, requestId: _issueKey),
        close: false,
        done: 'Stock issued',
      );
      // A request can be issued in several parts; each part needs its own key.
      if (succeeded) _issueKey = newRequestId();
      return succeeded;
    });
  }

  Future<void> _confirmReceipt(InventoryIssue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm receipt'),
        content: Text('Confirm the recipient received ${issue.number}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => stockSubmit(
        context,
        (stockProvider) =>
            stockProvider.act('inventory-issue-acknowledge', {'id': issue.id}),
        close: false,
        done: 'Receipt confirmed',
      ),
    );
  }

  Future<void> _return(InventoryIssue issue) async {
    await context.push(InventoryRoutes.inventoryIssueReturn, extra: issue);
    if (mounted) await _load();
  }

  Widget? _actionBar(InventoryIssueRequest request, ModuleAccess access) {
    if (request.isPending && access.can('inventory.issue.approve')) {
      return _ActionBar(
        children: [
          OutlinedButton(
            onPressed: _busy ? null : () => _reject(request),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _approve(request),
            child: const Text('Approve'),
          ),
        ],
      );
    }
    if (request.isIssuable && access.can('inventory.stock.operate')) {
      return _ActionBar(
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _issue(request),
            icon: const Icon(Icons.outbox_rounded, size: 18),
            label: const Text('Issue stock'),
          ),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final access = inventoryProvider.access;
    final request = _request;

    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (request == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError ?? 'Request not found'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else {
      final storeName =
          inventoryProvider.stores
              .where((store) => store.id == request.storeId)
              .firstOrNull
              ?.name ??
          request.storeId;
      final deciding =
          request.isPending && access.can('inventory.issue.approve');
      final issuing =
          request.isIssuable && access.can('inventory.stock.operate');
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IssueSummary(request: request, storeName: storeName),
            IssueItems(
              request: request,
              itemName: stockProvider.itemName,
              approvedControllers: deciding ? _approved : null,
            ),
            if (issuing)
              IssueStockCard(
                request: request,
                itemName: stockProvider.itemName,
                quantityControllers: _issueNow,
                recipientType: _recipientType,
                recipientId: _recipientId,
                onRecipientType: (type) => setState(() {
                  _recipientType = type;
                  _recipientId = type == 'staff'
                      ? int.tryParse(request.createdBy)
                      : null;
                }),
                onRecipient: (id) => setState(() => _recipientId = id),
              ),
            if (_issues.isNotEmpty)
              IssueSection(
                title: 'Issuances (${_issues.length})',
                child: Column(
                  children: [
                    for (final issue in _issues)
                      IssuanceCard(
                        issue: issue,
                        itemName: stockProvider.itemName,
                        busy: _busy,
                        onConfirmReceipt: () => _confirmReceipt(issue),
                        onReturn: () => _return(issue),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(request?.number ?? 'Issue request'),
        actions: [
          if (request != null &&
              request.isPending &&
              request.createdBy == stockProvider.uid)
            TextButton(
              onPressed: _busy ? null : () => _end(request, cancel: true),
              child: const Text('Cancel request'),
            ),
          if (request != null &&
              request.isIssuable &&
              access.can('inventory.stock.operate'))
            TextButton(
              onPressed: _busy ? null : () => _end(request, cancel: false),
              child: const Text('Close request'),
            ),
        ],
      ),
      body: CenteredBody(maxWidth: 900, child: body),
      bottomNavigationBar: request == null ? null : _actionBar(request, access),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: child),
            ],
          ],
        ),
      ),
    ),
  );
}
