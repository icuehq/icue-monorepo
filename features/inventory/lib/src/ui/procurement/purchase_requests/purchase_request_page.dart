import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/widgets/purchase_request_detail_widgets.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:provider/provider.dart';

/// One purchase request: lines, history, and the next step for the caller (FRS 10.13).
class PurchaseRequestPage extends StatefulWidget {
  const PurchaseRequestPage({required this.requestId, super.key});

  final String requestId;

  @override
  State<PurchaseRequestPage> createState() => _PurchaseRequestPageState();
}

class _PurchaseRequestPageState extends State<PurchaseRequestPage> {
  InventoryPurchaseRequest? _request;
  String? _loadError;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (!mounted) return;
    final procurementProvider = context.read<ProcurementProvider>();
    final request = await procurementProvider.request(widget.requestId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _request = request;
      _loadError = request == null
          ? procurementProvider.errorMessage ?? 'Request not found'
          : null;
    });
  }

  /// Runs [value] on this request, then reloads it so the screen shows the new state.
  Future<void> _act(
    String value,
    Map<String, Object?> extra,
    String done,
  ) async {
    setState(() => _busy = true);
    final succeeded = await procSubmit(
      context,
      (procurementProvider) =>
          procurementProvider.act(value, {'id': widget.requestId, ...extra}),
      close: false,
      done: done,
    );
    if (succeeded && mounted) await _load();
    if (mounted) setState(() => _busy = false);
  }

  /// Asks for a comment; null when cancelled. Returns '' for an empty optional comment.
  Future<String?> _askComment({
    required String title,
    required String action,
    required bool required,
    bool destructive = false,
  }) => showDialog<String>(
    context: context,
    builder: (context) {
      final comment = TextEditingController();
      String? error;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: comment,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: required ? 'Comment' : 'Comment (optional)',
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
                backgroundColor: destructive
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
              onPressed: () {
                if (required && comment.text.trim().isEmpty) {
                  return setDialogState(() => error = 'A comment is required');
                }
                Navigator.pop(context, comment.text.trim());
              },
              child: Text(action),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _decide(
    String decision,
    String title,
    String action,
    String done, {
    required bool required,
    bool destructive = false,
  }) async {
    final comment = await _askComment(
      title: title,
      action: action,
      required: required,
      destructive: destructive,
    );
    if (comment == null || !mounted) return;
    await _act('inventory-purchaseRequest-decide', {
      'decision': decision,
      'comment': comment,
    }, done);
  }

  Future<void> _cancel() async {
    final reason = await _askComment(
      title: 'Cancel request',
      action: 'Cancel request',
      required: false,
      destructive: true,
    );
    if (reason == null || !mounted) return;
    await _act('inventory-purchaseRequest-cancel', {
      'reason': reason,
    }, 'Request cancelled');
  }

  /// Opens [route]; the request is reloaded on return since the other screen may have changed it.
  Future<void> _open(String route, Object extra) async {
    await context.push(route, extra: extra);
    if (mounted) await _load();
  }

  Widget? _actionBar(
    InventoryPurchaseRequest request,
    bool own,
    InventoryProvider inventoryProvider,
  ) {
    final access = inventoryProvider.access;
    final theme = Theme.of(context);
    final List<Widget> buttons;
    if (request.isPending && access.can('inventory.purchaseRequest.approve')) {
      buttons = [
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _decide(
                  'reject',
                  'Reject request',
                  'Reject',
                  'Request rejected',
                  required: true,
                  destructive: true,
                ),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
          ),
          child: const Text('Reject'),
        ),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _decide(
                  'revise',
                  'Return for revision',
                  'Return',
                  'Returned for revision',
                  required: true,
                ),
          child: const Text('Return'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _decide(
                  'approve',
                  'Approve request',
                  'Approve',
                  'Request approved',
                  required: false,
                ),
          child: const Text('Approve'),
        ),
      ];
    } else if (own && request.isEditable) {
      buttons = [
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _open(
                  InventoryRoutes.inventoryPurchaseRequestForm,
                  request,
                ),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _act(
                  'inventory-purchaseRequest-submit',
                  {},
                  'Submitted for approval',
                ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit'),
        ),
      ];
    } else if (request.isOrderable && access.can('inventory.procure.operate')) {
      buttons = [
        OutlinedButton.icon(
          onPressed: () => _open(InventoryRoutes.inventoryPurchaseOrderForm, (
            request,
            null,
            null,
          )),
          icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
          label: const Text('Direct PO'),
        ),
        FilledButton.icon(
          onPressed: () => _open(InventoryRoutes.inventoryQuotations, request),
          icon: const Icon(Icons.request_quote_outlined, size: 18),
          label: const Text('Quotations'),
        ),
      ];
    } else {
      return null;
    }
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              for (final (index, button) in buttons.indexed) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(child: button),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final request = _request;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Purchase request')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError ?? 'Request not found'),
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
    }

    final own = request.createdBy == procurementProvider.uid;
    final canCancel = own && request.isCancellable;
    return Scaffold(
      appBar: AppBar(
        title: Text(request.number),
        actions: [
          if (canCancel)
            PopupMenuButton<String>(
              onSelected: (_) => _cancel(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cancel', child: Text('Cancel request')),
              ],
            ),
        ],
      ),
      body: CenteredBody(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PurchaseSummary(request: request),
              PurchaseItems(
                request: request,
                itemName: procurementProvider.itemName,
              ),
              if (request.history.isNotEmpty)
                PurchaseHistory(history: request.history),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _actionBar(request, own, inventoryProvider),
    );
  }
}
