import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// One scan input (architecture §11): type or use a USB / Bluetooth scanner or RFID reader in
/// keyboard-wedge mode (Enter submits), or tap the camera button to read a barcode / QR code.
class ScanField extends StatefulWidget {
  const ScanField({
    required this.hint,
    required this.onScan,
    this.onChanged,
    this.clearOnScan = false,
    this.autofocus = false,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onScan;
  final ValueChanged<String>? onChanged;
  final bool clearOnScan;
  final bool autofocus;

  @override
  State<ScanField> createState() => _ScanFieldState();
}

class _ScanFieldState extends State<ScanField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final code = v.trim();
    if (code.isEmpty) return;
    widget.onScan(code);
    if (widget.clearOnScan) {
      _c.clear();
      widget.onChanged?.call('');
    }
  }

  Future<void> _camera() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1,
          child: MobileScanner(
            onDetect: (capture) {
              final v = capture.barcodes.firstOrNull?.rawValue;
              if (v != null) Navigator.of(ctx).pop(v);
            },
          ),
        ),
      ),
    );
    if (code == null || !mounted) return;
    _c.text = code;
    widget.onChanged?.call(code);
    _submit(code);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    autofocus: widget.autofocus,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: 'Scan with camera',
        icon: const Icon(Icons.qr_code_scanner),
        onPressed: _camera,
      ),
    ),
    onChanged: widget.onChanged,
    onSubmitted: _submit,
  );
}
