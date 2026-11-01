import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Sheet to reserve a book that is currently unavailable (FRS 11.12).
class ReservationSheet extends StatefulWidget {
  const ReservationSheet({super.key, this.book});

  final LibBook? book;

  static Future<void> show(BuildContext context, {LibBook? book}) =>
      showInvSheet(context, () => ReservationSheet(book: book));

  @override
  State<ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<ReservationSheet> {
  final _erpId = TextEditingController();
  final _bookSearch = TextEditingController();
  String _memberType = 'student';
  LibBook? _selectedBook;
  String? _libraryId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.book;
  }

  @override
  void dispose() {
    _erpId.dispose();
    _bookSearch.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final erp = int.tryParse(_erpId.text.trim());
    if (erp == null) return invSnack(context, 'Enter the member ERP ID');
    final book = _selectedBook;
    if (book == null) return invSnack(context, 'Select a book to reserve');
    final libId = _libraryId;
    if (libId == null) return invSnack(context, 'Select a library');

    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final ok = await p.createReservation({
      'memberId': '${_memberType}_$erp',
      'catalogueId': book.id,
      'libraryId': libId,
    });
    if (!mounted) return;
    if (ok) {
      nav.pop(true);
      invSnack(context, 'Reservation placed');
    } else {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Could not place reservation');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final libs = [
      for (final l in p.libraries)
        if (l.active && p.access.campuses.contains(l.campusId)) l,
    ];
    if (_libraryId == null && libs.isNotEmpty) {
      _libraryId = libs.first.id;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reserve a book', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'student', label: Text('Student')),
                ButtonSegment(value: 'teacher', label: Text('Teacher')),
              ],
              selected: {_memberType},
              onSelectionChanged: (s) => setState(() => _memberType = s.first),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _erpId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ERP ID'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.book != null)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(widget.book!.title),
            subtitle: Text(widget.book!.authorLine),
          )
        else
          Autocomplete<LibBook>(
            displayStringForOption: (b) => b.title,
            optionsBuilder: (val) async {
              final q = val.text.trim();
              if (q.isEmpty) return const [];
              final res = await p.searchBooks(q, limit: 10);
              return res.items;
            },
            onSelected: (b) => setState(() => _selectedBook = b),
            fieldViewBuilder: (ctx, controller, focus, onFieldSubmitted) =>
                TextField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    labelText: 'Search book by title, author or ISBN',
                  ),
                ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _libraryId,
          decoration: const InputDecoration(labelText: 'Preferred library'),
          items: [
            for (final l in libs)
              DropdownMenuItem(value: l.id, child: Text(l.name)),
          ],
          onChanged: (v) => setState(() => _libraryId = v),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Reserve'),
        ),
      ],
    );
  }
}
