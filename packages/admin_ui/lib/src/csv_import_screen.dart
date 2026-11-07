import 'package:admin_ui/src/adaptive.dart';
import 'package:admin_ui/src/form_helpers.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What the user needs to know about one importable record type.
class ImportKind {
  const ImportKind({
    required this.type,
    required this.columns,
    required this.hint,
    required this.canImport,
  });

  final String type;
  final List<String> columns;
  final String hint;
  final bool canImport;
}

/// Sends one request of rows; returns the callable result (`created`, `results`) or null with the error in [errorMessage].
typedef ImportRunner = Future<Map<String, dynamic>?> Function(
  String type,
  String importId,
  List<Map<String, String>> rows,
);

/// Paste a CSV of master data; every row goes through the same rules as a single save.
class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({
    required this.kinds,
    required this.run,
    required this.errorMessage,
    this.appBarBottom,
    super.key,
  });

  final List<ImportKind> kinds;
  final ImportRunner run;
  final String? Function() errorMessage;

  /// Shown under the app bar, e.g. the tabs of the module group this screen belongs to.
  final PreferredSizeWidget? appBarBottom;

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  static const _rowsPerRequest = 200;

  final _csv = TextEditingController();
  late ImportKind _kind;
  var _isImporting = false;
  String? _summary;
  List<String> _errors = [];

  List<ImportKind> get _allowed =>
      widget.kinds.where((importKind) => importKind.canImport).toList();

  @override
  void initState() {
    super.initState();
    _kind = _allowed.first;
  }

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final rows = parseCsv(_csv.text);
    if (rows.isEmpty) {
      return showMessage(context, 'Paste a header row and data');
    }
    final missing = _kind.columns
        .take(2)
        .where((column) => !rows.first.containsKey(column));
    if (missing.isNotEmpty) {
      return showMessage(context, 'Missing column: ${missing.join(', ')}');
    }
    setState(() {
      _isImporting = true;
      _summary = null;
      _errors = [];
    });
    final run = DateTime.now().millisecondsSinceEpoch;
    var created = 0;
    final errors = <String>[];
    for (var start = 0; start < rows.length; start += _rowsPerRequest) {
      final result = await widget.run(
        _kind.type,
        'imp_${run}_${start ~/ _rowsPerRequest}',
        rows.skip(start).take(_rowsPerRequest).toList(),
      );
      if (result == null) {
        errors.add(widget.errorMessage() ?? 'Import stopped');
        break;
      }
      created += (result['created'] as num).toInt();
      for (final row
          in (result['results'] as List).cast<Map<String, dynamic>>()) {
        if (row['ok'] != true) {
          errors.add(
            'Row ${start + (row['row'] as num).toInt() + 2}: ${row['error']}',
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _isImporting = false;
      _summary = '$created of ${rows.length} rows imported';
      _errors = errors;
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = _kind.columns.join(',');
    return Scaffold(
      appBar: AppBar(title: const Text('Import'), bottom: widget.appBarBottom),
      body: CenteredBody(
        maxWidth: Breakpoints.formMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButton<ImportKind>(
              isExpanded: true,
              value: _kind,
              items: [
                for (final importKind in _allowed)
                  DropdownMenuItem(
                    value: importKind,
                    child: Text(importKind.type),
                  ),
              ],
              onChanged: _isImporting
                  ? null
                  : (importKind) => setState(() => _kind = importKind!),
            ),
            Text(
              'Columns: $header\n${_kind.hint} Up to $_rowsPerRequest rows per request.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy header row'),
              onPressed: () => Clipboard.setData(ClipboardData(text: header)),
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
              onPressed: _isImporting ? null : _import,
              child: Text(_isImporting ? 'Importing…' : 'Import'),
            ),
            if (_summary != null) ...[
              const SizedBox(height: 12),
              Text(_summary!, style: Theme.of(context).textTheme.titleMedium),
              for (final error in _errors)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
