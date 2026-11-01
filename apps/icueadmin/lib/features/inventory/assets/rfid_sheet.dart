import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Attaches (scan or type the tag) or clears an asset's RFID tag.
class RfidSheet extends StatefulWidget {
  const RfidSheet({required this.asset, super.key});

  final InvAsset asset;

  @override
  State<RfidSheet> createState() => _RfidSheetState();
}

class _RfidSheetState extends State<RfidSheet> {
  var _busy = false;

  Future<void> _save(String? tag) async {
    setState(() => _busy = true);
    final p = context.read<AssetsProvider>();
    final nav = Navigator.of(context);
    final res = await p.act('inv-asset-setRfid', {
      'id': widget.asset.id,
      'rfidTag': tag,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) {
      invSnack(context, p.errorMessage ?? 'Could not save');
    } else {
      nav.pop();
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
