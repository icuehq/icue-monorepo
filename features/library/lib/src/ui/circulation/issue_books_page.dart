import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_books_card.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_member_card.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_scan_item_card.dart';
import 'package:school_library/src/ui/shared/person_picker.dart';

/// Issue books at the circulation desk: select borrower and scan books (FRS 11.9).
class IssueBooksPage extends StatefulWidget {
  const IssueBooksPage({this.copy, super.key});

  /// A book already scanned before the page opened; issued automatically once borrower is selected.
  final LibraryCopy? copy;

  @override
  State<IssueBooksPage> createState() => _IssueBooksPageState();
}

class _IssueBooksPageState extends State<IssueBooksPage> {
  /// Scanned copies waiting for the Issue Book(s) button, in scan order.
  final List<IssueScanRecord> _queue = [];

  LibraryPerson? _person;
  LibraryMember? _member;
  bool _busy = false;

  /// Issue attempts in this session, newest first.
  final List<IssueScanRecord> _records = [];

  @override
  void initState() {
    super.initState();
    final copy = widget.copy;
    if (copy != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enqueue(copy));
    }
  }

  Future<void> _found(LibraryPerson? person) async {
    if (person == null) {
      setState(() {
        _person = null;
        _member = null;
      });
      return;
    }
    final libraryProvider = context.read<LibraryProvider>();
    setState(() {
      _person = person;
      _busy = true;
    });
    try {
      final member = await libraryProvider.member(person.personErpId);
      if (mounted) {
        setState(() => _member = member);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Looks the barcode up and queues it; nothing is issued until the button.
  Future<void> _scan(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _person == null || _busy) return;

    final libraryProvider = context.read<LibraryProvider>();
    setState(() => _busy = true);
    try {
      final copy = await libraryProvider.findCopy(code);
      if (!mounted) return;
      if (copy == null) {
        _notify('No copy found with barcode "$code"');
        return;
      }
      await _enqueue(copy);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _enqueue(LibraryCopy copy) async {
    final alreadyScanned =
        _queue.any((record) => record.copy?.id == copy.id) ||
        _records.any((record) => record.success && record.copy?.id == copy.id);
    if (alreadyScanned) {
      _notify('Book "${copy.barcode}" is already scanned');
      return;
    }
    final book = await context.read<LibraryProvider>().book(copy.catalogueId);
    if (!mounted) return;
    setState(() {
      _queue.add(
        IssueScanRecord(
          barcode: copy.barcode,
          success: false,
          isPending: true,
          message: '',
          timestamp: DateTime.now(),
          title: book?.title ?? copy.barcode,
          authors: book?.authors.join(', '),
          copy: copy,
        ),
      );
    });
  }

  /// Issues every queued copy to the selected borrower.
  Future<void> _issueQueued() async {
    final person = _person;
    if (person == null || _busy || _queue.isEmpty) return;

    final libraryProvider = context.read<LibraryProvider>();
    final queued = List.of(_queue);
    setState(() => _busy = true);
    try {
      for (final item in queued) {
        final success = await libraryProvider.issueLoan({
          'person': person.toPayload(),
          'barcode': item.copy!.id,
        });
        if (!mounted) return;
        final member = _member;
        setState(() {
          _queue.remove(item);
          _records.insert(
            0,
            IssueScanRecord(
              barcode: item.barcode,
              success: success,
              message: success
                  ? 'Issued successfully'
                  : libraryProvider.errorMessage ?? 'Issue failed',
              timestamp: DateTime.now(),
              title: item.title,
              authors: item.authors,
              copy: item.copy,
            ),
          );
          if (success && member != null) {
            _member = LibraryMember(
              id: member.id,
              memberType: member.memberType,
              personErpId: member.personErpId,
              name: member.name,
              classId: member.classId,
              activeLoans: member.activeLoans + 1,
              blocked: member.blocked,
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _changePerson() {
    if (_busy) return;
    setState(() {
      _person = null;
      _member = null;
    });
  }

  int get _successfulCount => _records.where((record) => record.success).length;

  Widget _buildBorrowerCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final person = _person;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrower',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        person == null
                            ? 'Search and select member'
                            : 'Selected borrower profile',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (person != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Colors.green.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (person == null)
              PersonPicker(autofocus: true, onChanged: _found)
            else
              IssueMemberCard(
                person: person,
                member: _member,
                onChange: _changePerson,
                disabled: _busy,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = _person;
    final isWide = context.isWide;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Books'),
        actions: [
          if (person != null && _successfulCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: IcueButton(
                  label: 'Finish',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.done_all_rounded,
                ),
              ),
            ),
        ],
      ),
      body: IcueCenteredBody(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 16,
              vertical: 16,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildBorrowerCard(context)),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 7,
                        child: IssueBooksCard(
                          person: person,
                          queue: _queue,
                          records: _records,
                          successfulCount: _successfulCount,
                          busy: _busy,
                          onScan: _scan,
                          onRemoveQueued: (record) =>
                              setState(() => _queue.remove(record)),
                          onIssue: _issueQueued,
                          onDone: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBorrowerCard(context),
                      const SizedBox(height: 16),
                      IssueBooksCard(
                        person: person,
                        queue: _queue,
                        records: _records,
                        successfulCount: _successfulCount,
                        busy: _busy,
                        onScan: _scan,
                        onRemoveQueued: (record) =>
                            setState(() => _queue.remove(record)),
                        onIssue: _issueQueued,
                        onDone: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
