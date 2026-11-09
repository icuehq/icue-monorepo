import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/book_scan_dialog.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_dialog.dart';

/// Opens the circulation flow when the librarian scans a book anywhere in the Library screens.
///
/// A keyboard-wedge scanner types the whole code within a few milliseconds and ends with Enter.
/// Keys typed by hand are slower, and keys typed into a text field are left to that field.
class LibraryScanListener extends StatefulWidget {
  const LibraryScanListener({required this.child, super.key});

  final Widget child;

  @override
  State<LibraryScanListener> createState() => _LibraryScanListenerState();
}

class _LibraryScanListenerState extends State<LibraryScanListener> {
  static const _maxKeyGap = Duration(milliseconds: 60);
  static const _minLength = 4;

  final _code = StringBuffer();
  Duration _lastKey = Duration.zero;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || _handling || !mounted) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.findAncestorWidgetOfExactType<EditableText>() != null) {
      _code.clear();
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _code.toString();
      _code.clear();
      if (code.length < _minLength) return false;
      _handle(code);
      return true;
    }
    final character = event.character;
    if (character == null || character.length != 1) return false;
    if (event.timeStamp - _lastKey > _maxKeyGap) _code.clear();
    _lastKey = event.timeStamp;
    _code.write(character);
    return false;
  }

  Future<void> _handle(String code) async {
    _handling = true;
    try {
      final libraryProvider = context.read<LibraryProvider>();
      final copy = await libraryProvider.findCopy(code);
      if (!mounted) return;
      if (copy == null) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded),
            title: const Text('Invalid barcode'),
            content: Text('No book copy found for "$code".'),
            actions: [
              AppButton(
                autofocus: true,
                label: 'OK',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        );
        return;
      }
      final loan = await libraryProvider.activeLoanOf(copy.id);
      final book = await libraryProvider.book(copy.catalogueId);
      if (!mounted) return;
      final proceed = await BookScanDialog.show(
        context,
        copy: copy,
        book: book,
        loan: loan,
      );
      if (!proceed || !mounted) return;
      if (loan == null) {
        await context.push<void>(LibraryRoutes.libraryIssue, extra: copy);
        return;
      }
      await LoanDialog.show(context, loan, book?.title ?? loan.barcode);
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
