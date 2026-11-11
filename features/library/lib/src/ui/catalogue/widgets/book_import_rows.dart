import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/import/book_import.dart';

/// A book of the sheet with its copies, or what importing it did.
class BookImportBookTile extends StatelessWidget {
  const BookImportBookTile({required this.book, this.result, super.key});

  final BookImportBook book;
  final BookImportResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;
    final copies = book.copies.length;
    final (icon, color, text) = switch (result) {
      null => (
        Icons.check_circle_outline_rounded,
        Colors.green.shade700,
        '$copies ${copies == 1 ? 'copy' : 'copies'} · barcodes ${book.copies.first.barcode}${copies > 1 ? ' … ${book.copies.last.barcode}' : ''}',
      ),
      BookImportResult(:final error?) => (
        Icons.error_rounded,
        theme.colorScheme.error,
        '${result.copiesAdded} of $copies copies added. $error',
      ),
      _ => (
        Icons.check_circle_rounded,
        Colors.green.shade700,
        '${result.created ? 'New book' : 'Existing book'} · ${result.copiesAdded} ${result.copiesAdded == 1 ? 'copy' : 'copies'} added',
      ),
    };
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(text, style: TextStyle(color: color)),
    );
  }
}

/// A sheet row that cannot be imported, with its errors.
class BookImportIssueTile extends StatelessWidget {
  const BookImportIssueTile({required this.issue, super.key});

  final BookImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return ListTile(
      dense: true,
      leading: Icon(Icons.error_outline_rounded, color: color),
      title: Text(
        'Row ${issue.line} · ${issue.title.isEmpty ? '(no title)' : issue.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(issue.errors.join('\n'), style: TextStyle(color: color)),
    );
  }
}
