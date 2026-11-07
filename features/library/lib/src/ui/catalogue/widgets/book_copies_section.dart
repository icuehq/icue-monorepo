import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_card.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_dialog.dart';

/// Physical copies of a title (FRS 11.1 "view physical copies"), .
class BookCopiesSection extends StatefulWidget {
  const BookCopiesSection({super.key, required this.book});

  final LibraryBook book;

  @override
  State<BookCopiesSection> createState() => _BookCopiesSectionState();
}

class _BookCopiesSectionState extends State<BookCopiesSection> {
  List<LibraryCopy>? _copies;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final copies = await context.read<LibraryProvider>().copiesOf(
        widget.book.id,
      );
      if (mounted) setState(() => _copies = copies);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final copies = _copies;
    final available = copies
        ?.where((copy) => copy.status == 'available')
        .length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Physical Copies',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (copies != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${copies.length} copies · $available available',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else if (copies == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (copies.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No physical copies registered yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final copy in copies)
                CopyCard(
                  copy: copy,
                  libraryName:
                      libraryProvider.library(copy.libraryId)?.name ??
                      copy.libraryId,
                  onTap: () async {
                    await CopyDialog.show(context, copy, widget.book.title);
                    await _load();
                  },
                ),
          ],
        ),
      ),
    );
  }
}
