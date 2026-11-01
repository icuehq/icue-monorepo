import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Attaches (scan or type the tag) or clears an asset's RFID tag.
class RfidSheet extends StatefulWidget {
  const RfidSheet({required this.asset, super.key});

  final InventoryAsset asset;

  @override
  State<RfidSheet> createState() => _RfidSheetState();
}

class _RfidSheetState extends State<RfidSheet> {
  var _busy = false;

  Future<void> _save(String? tag) async {
    setState(() => _busy = true);
    final assetsProvider = context.read<AssetsProvider>();
    final navigator = Navigator.of(context);
    final result = await assetsProvider.act('inventory-asset-setRfid', {
      'id': widget.asset.id,
      'rfidTag': tag,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) {
      showMessage(context, assetsProvider.errorMessage ?? 'Could not save');
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('RFID tag', style: Theme.of(context).textTheme.titleLarge),
      Text('${widget.asset.name} · ${widget.asset.assetId}'),
      if (widget.asset.rfidTag != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Current tag: ${widget.asset.rfidTag}'),
        ),
      const SizedBox(height: 12),
      AbsorbPointer(
        absorbing: _busy,
        child: ScanField(
          hint: 'Scan or type the tag, then Enter',
          autofocus: true,
          onScan: _save,
        ),
      ),
      if (widget.asset.rfidTag != null)
        TextButton(
          onPressed: _busy ? null : () => _save(null),
          child: const Text('Remove tag'),
        ),
    ],
  );
}
