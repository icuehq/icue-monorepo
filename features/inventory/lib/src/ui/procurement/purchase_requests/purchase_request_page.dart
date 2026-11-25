import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/purchase_receive_page.dart';
import 'package:inventory/src/ui/procurement/purchase_requests/widgets/purchase_request_detail_widgets.dart';
import 'package:inventory/src/ui/procurement/shared/procurement_ui.dart';
import 'package:provider/provider.dart';

/// One purchase request: what was asked for, what arrived, and its history. Store staff edit it
/// until goods arrive, record each delivery, and close it when the rest will not come.
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
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
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

  Future<void> _close() async {
    final reason = await askText(
      context,
      title: 'Close request',
      label: 'Reason (optional)',
      hint: 'e.g. Vendor cannot supply the rest',
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final closed = await procSubmit(
      context,
      (procurementProvider) => procurementProvider.act(
        'inventory-purchaseRequest-close',
        {'id': widget.requestId, 'reason': reason},
      ),
      close: false,
      done: 'Request closed',
    );
    if (closed && mounted) await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(InventoryPurchaseRequest request) async {
    await context.push(
      InventoryRoutes.inventoryPurchaseRequestForm,
      extra: request,
    );
    if (mounted) await _load();
  }

  Future<void> _receive(InventoryPurchaseRequest request) async {
    await pushFormPage<bool>(
      context,
      () => PurchaseReceivePage(request: request),
    );
    // Reload even after a failure: lines saved before it are on the request.
    if (mounted) await _load();
  }

  Widget? _actionBar(
    InventoryPurchaseRequest request, {
    required bool isTabletOrWider,
    required bool isWide,
  }) {
    if (!request.isOpen) return null;
    final editButton = IcueButton(
      label: 'Edit',
      onPressed: _busy ? null : () => _edit(request),
      variant: IcueButtonVariant.outline,
      leadingIcon: Icons.edit_outlined,
    );
    final closeButton = IcueButton(
      label: 'Close request',
      onPressed: _busy ? null : _close,
      variant: IcueButtonVariant.outline,
      leadingIcon: Icons.block_rounded,
    );
    final receiveButton = IcueButton(
      label: 'Receive items',
      onPressed: _busy ? null : () => _receive(request),
      leadingIcon: Icons.move_to_inbox_rounded,
    );

    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 16,
            vertical: 12,
          ),
          child: isTabletOrWider
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    closeButton,
                    if (request.isEditable) ...[
                      const SizedBox(width: 12),
                      editButton,
                    ],
                    const SizedBox(width: 12),
                    receiveButton,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (request.isEditable) ...[
                          Expanded(child: editButton),
                          const SizedBox(width: 10),
                        ] else ...[
                          Expanded(child: closeButton),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: receiveButton),
                      ],
                    ),
                    if (request.isEditable) ...[
                      const SizedBox(height: 8),
                      IcueButton(
                        label: 'Close request',
                        onPressed: _busy ? null : _close,
                        variant: IcueButtonVariant.outline,
                        leadingIcon: Icons.block_rounded,
                        isFullWidth: true,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final procurementProvider = context.watch<ProcurementProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final isWide = context.isWide;
    final isTabletOrWider =
        MediaQuery.sizeOf(context).width >= IcueBreakpoints.table;
    final request = _request;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Purchase Request')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _loadError ?? 'Request not found',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      IcueButton(
                        label: 'Try again',
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        variant: IcueButtonVariant.outline,
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final storeName = inventoryProvider.stores
        .where((store) => store.id == request.storeId)
        .firstOrNull
        ?.name;
    final summary = PurchaseSummary(request: request, storeName: storeName);
    final items = PurchaseItems(
      request: request,
      lineName: procurementProvider.lineName,
    );
    final history = request.history.isNotEmpty
        ? PurchaseHistory(history: request.history)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(request.number)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        summary,
                        if (history != null) ...[
                          const SizedBox(height: 16),
                          history,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: items),
                ],
              )
            else ...[
              summary,
              const SizedBox(height: 16),
              items,
              if (history != null) ...[const SizedBox(height: 16), history],
            ],
          ],
        ),
      ),
      bottomNavigationBar: _actionBar(
        request,
        isTabletOrWider: isTabletOrWider,
        isWide: isWide,
      ),
    );
  }
}
