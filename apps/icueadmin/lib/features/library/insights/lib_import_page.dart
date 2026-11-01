import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart' show parseCsv;
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Paste a CSV of titles, copies or members; every row goes through the same rules as a single save.
class LibImportPage extends StatefulWidget {
  const LibImportPage({super.key});

  @override
  State<LibImportPage> createState() => _LibImportPageState();
}

class _LibImportPageState extends State<LibImportPage> {
  static const _chunk = 200;
  static const _hints = {
    'catalogue': 'Authors and keywords separated by ";". categoryCode of an existing category. Existing titles are rejected.',
    'copies': 'One opening-stock acquisition per row: isbn13 of an existing title, libraryCode, qty (default 1). Accession numbers are generated.',
    'members': 'memberType student or teacher; libraryCodes separated by ";"; dates yyyy-mm-dd. Existing members are rejected.',
  };

  final _csv = TextEditingController();
  late String _type;
  var _busy = false;
  String? _summary;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    final a = context.read<LibraryProvider>().access;
    _type = libImportPerms.entries.firstWhere((e) => a.can(e.value)).key;
  }

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final rows = parseCsv(_csv.text);
    if (rows.isEmpty) return invSnack(context, 'Paste a header row and data');
    final missing = libImportColumns[_type]!
        .take(2)
        .where((c) => !rows.first.containsKey(c));
    if (missing.isNotEmpty) {
      return invSnack(context, 'Missing column: ${missing.join(', ')}');
    }
    setState(() {
      _busy = true;
      _summary = null;
      _errors = [];
    });
    final p = context.read<LibraryProvider>();
    final run = DateTime.now().millisecondsSinceEpoch;
    var created = 0;
    final errors = <String>[];
    for (var at = 0; at < rows.length; at += _chunk) {
      final res = await p.importRows(
        _type,
        'imp_${run}_${at ~/ _chunk}',
        rows.skip(at).take(_chunk).toList(),
      );
      if (res == null) {
        errors.add(p.errorMessage ?? 'Import stopped');
        break;
      }
      created += (res['created'] as num).toInt();
      for (final r in (res['results'] as List).cast<Map<String, dynamic>>()) {
        if (r['ok'] != true) {
          errors.add(
            'Row ${at + (r['row'] as num).toInt() + 2}: ${r['error']}',
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _summary = '$created of ${rows.length} rows imported';
      _errors = errors;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = context.read<LibraryProvider>().access;
    final cols = libImportColumns[_type]!.join(',');
    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButton<String>(
            isExpanded: true,
            value: _type,
            items: [
              for (final e in libImportPerms.entries)
                if (a.can(e.value))
                  DropdownMenuItem(value: e.key, child: Text(e.key)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _type = v!),
          ),
          Text(
            'Columns: $cols\n${_hints[_type]} Up to $_chunk rows per request.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy header row'),
            onPressed: () => Clipboard.setData(ClipboardData(text: cols)),
          ),
          TextField(
            controller: _csv,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: 'Paste CSV, header row first',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _run,
            child: Text(_busy ? 'Importing…' : 'Import'),
          ),
          if (_summary != null) ...[
            const SizedBox(height: 12),
            Text(_summary!, style: Theme.of(context).textTheme.titleMedium),
            for (final e in _errors)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ],
      ),
    );
  }
}
