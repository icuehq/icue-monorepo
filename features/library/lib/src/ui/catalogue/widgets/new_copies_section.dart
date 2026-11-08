import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Add-book fields for the copies created with a new title: how many, and in which library.
class NewCopiesSection extends StatefulWidget {
  const NewCopiesSection({
    required this.copies,
    required this.barcodes,
    required this.libraries,
    required this.libraryId,
    required this.onLibraryChanged,
    super.key,
  });

  final TextEditingController copies;

  /// One controller per copy, grown and shrunk here; the owner disposes them.
  final List<TextEditingController> barcodes;
  final List<SchoolLibrary> libraries;
  final String? libraryId;
  final ValueChanged<String?> onLibraryChanged;

  @override
  State<NewCopiesSection> createState() => _NewCopiesSectionState();
}

class _NewCopiesSectionState extends State<NewCopiesSection> {
  /// Barcodes already found in the library, so they show as invalid right after the scan.
  final _taken = <String>{};

  Future<void> _checkTaken(String value) async {
    final code = value.trim();
    if (code.isEmpty || _taken.contains(code)) return;
    final copy = await context.read<LibraryProvider>().findCopy(code);
    if (copy != null && mounted) setState(() => _taken.add(code));
  }

  @override
  void initState() {
    super.initState();
    widget.copies.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.copies.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final count = (int.tryParse(widget.copies.text.trim()) ?? 0).clamp(0, 100);
    final barcodes = widget.barcodes;
    if (count == barcodes.length) return;
    final removed = <TextEditingController>[];
    while (barcodes.length > count) {
      removed.add(barcodes.removeLast());
    }
    while (barcodes.length < count) {
      barcodes.add(TextEditingController());
    }
    // Fields still use the removed controllers until the next frame builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in removed) {
        controller.dispose();
      }
      if (mounted) setState(() {});
    });
  }

  String? _unique(String? value, int index) {
    final code = value?.trim().toLowerCase() ?? '';
    if (code.isEmpty) return 'Scan or enter the barcode';
    if (_taken.contains(value!.trim())) return 'This barcode already exists';
    final repeated = [
      for (final (other, controller) in widget.barcodes.indexed)
        if (other != index && controller.text.trim().toLowerCase() == code)
          other,
    ];
    return repeated.isEmpty ? null : 'Same as copy ${repeated.first + 1}';
  }

  Widget _row(BuildContext context, List<Widget> fields) => context.isWide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 14),
            Expanded(child: fields[1]),
          ],
        )
      : Column(children: [fields[0], const SizedBox(height: 14), fields[1]]);

  @override
  Widget build(BuildContext context) {
    final copies = widget.copies;
    final libraries = widget.libraries;
    return FormSectionCard(
      title: 'Copies',
      icon: Icons.copy_rounded,
      children: [
        _row(context, [
          AppTextField(
            controller: copies,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final number = int.tryParse(value?.trim() ?? '');
              return number == null || number > 100
                  ? 'Enter 0 to 100 copies'
                  : null;
            },
            label: 'Number of copies *',
            hintText: 'e.g. 1',
            icon: Icons.copy_rounded,
            helperText: '0 adds the title only',
          ),
          AppDropdown<String>(
            value: widget.libraryId,
            items: [
              for (final library in libraries)
                DropdownMenuItem(value: library.id, child: Text(library.name)),
            ],
            onChanged: widget.onLibraryChanged,
            validator: (value) =>
                value == null && (int.tryParse(copies.text.trim()) ?? 0) > 0
                ? 'Select a library'
                : null,
            icon: Icons.local_library_outlined,
            label: 'Library',
            helperText: libraries.isEmpty ? 'No active library found' : null,
          ),
        ]),
        if (widget.barcodes.isNotEmpty) ...[
          Text(
            'Scan the barcode of each copy; it moves to the next field automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // Own focus group: otherwise "next" follows screen position and jumps
          // to the neighbouring column (e.g. Pages) on wide layouts.
          FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
              children: [
                for (final (index, controller) in widget.barcodes.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
                    child: AppTextField(
                      key: ObjectKey(controller),
                      controller: controller,
                      textInputAction: index == widget.barcodes.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      validator: (value) => _unique(value, index),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onFieldSubmitted: _checkTaken,
                      label: 'Copy ${index + 1} barcode *',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
