import 'package:flutter/material.dart';

/// One scan input (architecture §11): type or use a USB / Bluetooth scanner or RFID reader in
/// keyboard-wedge mode (Enter submits), or type a code and tap the search button.
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

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focusNode,
    autofocus: widget.autofocus,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.qr_code_scanner),
      suffixIcon: IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.search),
        onPressed: () => _submit(_controller.text),
      ),
    ),
    onChanged: widget.onChanged,
    onSubmitted: _submit,
  );
}
