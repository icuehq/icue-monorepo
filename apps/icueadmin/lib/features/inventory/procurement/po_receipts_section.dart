import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Inspection history of a purchase order: every delivery with its accepted / rejected quantities.
class PoReceiptsSection extends StatefulWidget {
  const PoReceiptsSection({required this.orderId, super.key});

  final String orderId;

  @override
  State<PoReceiptsSection> createState() => _PoReceiptsSectionState();
}

class _PoReceiptsSectionState extends State<PoReceiptsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadReceipts(
        context.read<InventoryProvider>().access,
        widget.orderId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProcurementProvider>();
    if (p.receipts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Deliveries', style: Theme.of(context).textTheme.titleSmall),
        for (final g in p.receipts)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${g.number} · ${g.date}'
              '${g.reference == null ? '' : ' · ${g.reference}'}',
            ),
            subtitle: Text(
              [
                for (final l in g.lines)
                  '${p.itemName(l.itemId)}: ${fmtQty(l.accepted)} accepted'
                      '${l.rejected > 0 ? ', ${fmtQty(l.rejected)} rejected' : ''}'
                      '${l.condition == null ? '' : ' (${l.condition})'}',
              ].join('\n'),
            ),
            trailing: Text(g.result),
          ),
      ],
    );
  }
}
