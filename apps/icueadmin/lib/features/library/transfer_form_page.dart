import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/features/library/widgets/transfer_widgets.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Request a transfer of available copies from one library to another (FRS 11.15).
class LibraryTransferFormPage extends StatefulWidget {
  const LibraryTransferFormPage({super.key});

  @override
  State<LibraryTransferFormPage> createState() =>
      _LibraryTransferFormPageState();
}

class _LibraryTransferFormPageState extends State<LibraryTransferFormPage> {
  static const _maxCopies = 100;

  final _remarks = TextEditingController();
  final _requestId = newRequestId();

  /// Scanned copies, in scan order (the accession number is the copy ID).
  final _copies = <LibraryCopy>[];
  String? _from;
  String? _to;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final libraryProvider = context.read<LibraryProvider>();
      if (libraryProvider.libraries.isEmpty) {
        await libraryProvider.loadMasters();
      }
      if (!mounted) return;
      // A single eligible source library needs no choosing.
      final sources = _sources(libraryProvider);
      if (sources.length == 1) setState(() => _from = sources.single.id);
    });
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  /// Active libraries on the user's campuses; the source must be one of them.
  List<SchoolLibrary> _sources(LibraryProvider libraryProvider) => [
    for (final schoolLibrary in libraryProvider.libraries)
      if (schoolLibrary.active &&
          onCampus(libraryProvider.access, schoolLibrary.campusId))
        schoolLibrary,
  ];

  void _setSource(String? value) {
    if (value == _from) return;
    setState(() {
      _from = value;
      if (_to == value) _to = null;
      if (_copies.isNotEmpty) {
        _copies.clear();
        showMessage(context, 'Source changed. Scan the copies again.');
      }
    });
  }

  Future<void> _add(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    final from = _from;
    if (copy == null) {
      showMessage(context, 'No copy found for "$code"');
    } else if (_copies.any((added) => added.id == copy.id)) {
      showMessage(context, '${copy.accessionNumber} is already added');
    } else if (from != null && copy.libraryId != from) {
      showMessage(
        context,
        '${copy.accessionNumber} is in '
        '${libraryProvider.library(copy.libraryId)?.name ?? copy.libraryId}, '
        'not the source library',
      );
    } else if (copy.status != 'available') {
      showMessage(
        context,
        '${copy.accessionNumber} is ${copy.status.replaceAll('_', ' ')}',
      );
    } else if (_copies.length >= _maxCopies) {
      showMessage(context, 'A transfer can carry $_maxCopies copies at most');
    } else if (!_sources(libraryProvider)
        .any((source) => source.id == copy.libraryId)) {
      showMessage(
        context,
        'You cannot transfer copies out of '
        '${libraryProvider.library(copy.libraryId)?.name ?? copy.libraryId}',
      );
    } else {
      setState(() {
        _from ??= copy.libraryId;
        if (_to == _from) _to = null;
        _copies.add(copy);
      });
    }
  }

  Future<void> _submit() async {
    if (_from == null || _to == null || _copies.isEmpty) {
      return showMessage(
        context,
        'Choose the destination and scan at least one copy',
      );
    }
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final saved = await libraryProvider.requestTransfer({
      'fromLibraryId': _from,
      'toLibraryId': _to,
      'copyIds': [for (final copy in _copies) copy.id],
      'remarks': ?blankToNull(_remarks),
    }, requestId: _requestId);
    if (!mounted) return;
    if (saved) {
      showMessage(context, 'Transfer requested');
      navigator.pop();
    } else {
      setState(() => _busy = false);
      showMessage(context, libraryProvider.errorMessage ?? 'Could not save');
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final sources = _sources(libraryProvider);
    final destinations = [
      for (final schoolLibrary in libraryProvider.libraries)
        if (schoolLibrary.active && schoolLibrary.id != _from) schoolLibrary,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('New transfer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _from,
            key: ValueKey('from-$_from'),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'From library',
              prefixIcon: Icon(Icons.outbox_rounded),
            ),
            items: [
              for (final schoolLibrary in sources)
                DropdownMenuItem(
                  value: schoolLibrary.id,
                  child: Text(schoolLibrary.name),
                ),
            ],
            onChanged: _setSource,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _to,
            key: ValueKey('to-$_from-$_to'),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'To library',
              prefixIcon: Icon(Icons.move_to_inbox_rounded),
            ),
            items: [
              for (final schoolLibrary in destinations)
                DropdownMenuItem(
                  value: schoolLibrary.id,
                  child: Text(schoolLibrary.name),
                ),
            ],
            onChanged: (value) => setState(() => _to = value),
          ),
          const SizedBox(height: 20),
          Text(
            'Copies (${_copies.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ScanField(
            hint: 'Scan or enter accession no. / barcode',
            clearOnScan: true,
            onScan: _add,
          ),
          const SizedBox(height: 8),
          if (_copies.isEmpty)
            Text(
              'Only available copies of the source library can be transferred.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 6,
              children: [
                for (final copy in _copies)
                  InputChip(
                    label: Text(copy.accessionNumber),
                    onDeleted: () => setState(() => _copies.remove(copy)),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarks,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Remarks (optional)'),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Requesting…' : 'Request transfer'),
            ),
          ),
        ),
      ),
    );
  }
}
