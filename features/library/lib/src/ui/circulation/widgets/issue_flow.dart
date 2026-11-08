import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/person_picker.dart';

/// Issue books in two steps: find the member by admission number, then scan copies one after another.
class IssueFlow extends StatefulWidget {
  const IssueFlow({this.copy, super.key});

  /// A book already scanned before the flow opened; it is issued once the member is found.
  final LibraryCopy? copy;

  static Future<void> show(BuildContext context, {LibraryCopy? copy}) =>
      showFormPage(context, () => IssueFlow(copy: copy));

  @override
  State<IssueFlow> createState() => _IssueFlowState();
}

class _IssueFlowState extends State<IssueFlow> {
  late LibraryCopy? _pending = widget.copy;
  LibraryPerson? _person;
  bool _busy = false;

  /// Outcome of each scan in this visit, newest first: (text, succeeded).
  final List<(String, bool)> _results = [];

  Future<void> _found(LibraryPerson? person) async {
    setState(() => _person = person);
    final scanned = _pending;
    _pending = null; // only the first member gets the pre-scanned book
    if (person != null && scanned != null) {
      await _issue(scanned.barcode);
    }
  }

  Future<void> _issue(String code) async {
    final person = _person;
    if (person == null || _busy) return;
    final libraryProvider = context.read<LibraryProvider>();
    setState(() => _busy = true);
    final copy = await libraryProvider.findCopy(code);
    final bool success;
    final String text;
    if (copy == null) {
      success = false;
      text = 'No copy found for "$code"';
    } else {
      success = await libraryProvider.issueLoan({
        'person': person.toPayload(),
        'barcode': copy.id,
      });
      text = success
          ? '${copy.barcode} issued'
          : '${copy.barcode}: ${libraryProvider.errorMessage ?? 'Failed'}';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _results.insert(0, (text, success));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final person = _person;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          person == null ? 'Step 1 of 2 · Member' : 'Step 2 of 2 · Books',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          person == null ? 'Who is borrowing?' : 'Scan the books to issue',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (person == null)
          PersonPicker(autofocus: true, onChanged: _found)
        else ...[
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(person.name),
              subtitle: Text(
                [
                  'ID ${person.personErpId}',
                  if (person.detail.isNotEmpty) person.detail,
                ].join(' · '),
              ),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _person = null;
                        _results.clear();
                      }),
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ScanField(
            autofocus: true,
            hint: 'Scan or type the copy barcode',
            onScan: _issue,
            clearOnScan: true,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          for (final (text, success) in _results)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: success ? Colors.green : theme.colorScheme.error,
              ),
              title: Text(text),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(
              _results.any((result) => result.$2) ? 'Done' : 'Cancel',
            ),
          ),
        ],
      ],
    );
  }
}
