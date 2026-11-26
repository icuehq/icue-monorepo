import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Looks up an asset by ID or RFID tag using a scanner or manual entry, returning the matched [InventoryAsset].
class AssetScanDialog extends StatefulWidget {
  const AssetScanDialog({super.key});

  static Future<InventoryAsset?> show(BuildContext context) =>
      showDialog<InventoryAsset>(
        context: context,
        builder: (_) => const AssetScanDialog(),
      );

  @override
  State<AssetScanDialog> createState() => _AssetScanDialogState();
}

class _AssetScanDialogState extends State<AssetScanDialog> {
  bool _searching = false;
  String? _error;

  Future<void> _lookup(String code) async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    final assetsProvider = context.read<AssetsProvider>();
    final asset = await assetsProvider.findByCode(code);
    if (!mounted) return;
    if (asset != null) {
      Navigator.of(context).pop(asset);
      return;
    }
    setState(() {
      _searching = false;
      _error = assetsProvider.errorMessage ?? 'No asset matching "$code"';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner_rounded),
          SizedBox(width: 10),
          Text('Scan asset ID or tag'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use a barcode or RFID scanner, or enter an asset ID or tag and press Enter.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            IcueScanField(
              hint: 'Asset ID or RFID tag',
              autofocus: true,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onScan: _lookup,
            ),
            if (_searching) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
