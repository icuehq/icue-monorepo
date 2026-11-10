import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// One scan input (architecture §11): type or use a USB / Bluetooth scanner or RFID reader in
/// keyboard-wedge mode (Enter submits), or tap the camera button to read a barcode / QR code.
class IcueScanField extends StatefulWidget {
  const IcueScanField({
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
  State<IcueScanField> createState() => _ScanFieldState();
}

class _ScanFieldState extends State<IcueScanField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    widget.onScan(code);
    if (widget.clearOnScan) {
      _controller.clear();
      widget.onChanged?.call('');
      // A scanner types fast and presses Enter, which drops focus; keep it for the next scan.
      _focusNode.requestFocus();
    }
  }

  Future<void> _camera() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1,
          child: MobileScanner(
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null) Navigator.of(context).pop(value);
            },
          ),
        ),
      ),
    );
    if (code == null || !mounted) return;
    _controller.text = code;
    widget.onChanged?.call(code);
    _submit(code);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focusNode,
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
