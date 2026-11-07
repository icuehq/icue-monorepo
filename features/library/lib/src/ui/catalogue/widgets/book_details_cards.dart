import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

/// A bordered card with an icon + title header, shared by the book details sections.
class BookSectionCard extends StatelessWidget {
  const BookSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.surfaceContainerHighest).withValues(
          alpha: color == null ? 0.6 : 0.12,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title block: cover placeholder, title, authors, tags and the catalogue switch.
class BookHeroCard extends StatelessWidget {
  const BookHeroCard({
    required this.book,
    required this.categoryName,
    required this.canEdit,
    required this.onActiveChanged,
    super.key,
  });

  final LibraryBook book;
  final String? categoryName;
  final bool canEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.isWide;
    final subtitle = book.subtitle ?? '';

    final cover = Container(
      width: isWide ? 76 : 56,
      height: isWide ? 100 : 76,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        size: isWide ? 38 : 28,
        color: theme.colorScheme.primary,
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style:
              (isWide
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (book.authorLine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'by ${book.authorLine}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(
              book.active ? 'Active' : 'Inactive',
              color: book.active ? Colors.green.shade700 : Colors.grey.shade700,
              icon: book.active
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
            ),
            if (categoryName != null)
              _Tag(categoryName!, icon: Icons.category_outlined),
            if (book.isbn != null && book.isbn!.isNotEmpty)
              _Tag('ISBN ${book.isbn}', icon: Icons.qr_code_2_rounded),
            if (book.shelf != null && book.shelf!.isNotEmpty)
              _Tag(book.shelf!, icon: Icons.location_on_outlined),
          ],
        ),
      ],
    );

    final activeSwitch = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Active in catalogue', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 8),
        Switch(value: book.active, onChanged: onActiveChanged),
      ],
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                SizedBox(width: isWide ? 24 : 14),
                Expanded(child: details),
                if (isWide && canEdit) ...[
                  const SizedBox(width: 16),
                  activeSwitch,
                ],
              ],
            ),
            if (!isWide && canEdit) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              Align(alignment: Alignment.centerRight, child: activeSwitch),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bibliographic facts as a grid of one to three columns, by the card's width.
class BookInfoCard extends StatelessWidget {
  const BookInfoCard({required this.book, super.key});

  final LibraryBook book;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String?)>[
      (Icons.tag_rounded, 'ISBN', book.isbn),
      (Icons.business_outlined, 'Publisher', book.publisher),
      (Icons.event_outlined, 'Publication year', book.year?.toString()),
      (Icons.auto_stories_outlined, 'Edition', book.edition),
      (Icons.translate_outlined, 'Language', book.language),
      (Icons.library_books_outlined, 'Pages', book.pages?.toString()),
      (Icons.location_on_outlined, 'Shelf / Location', book.shelf),
    ];
    return BookSectionCard(
      title: 'Bibliographic information',
      icon: Icons.info_outline_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640
              ? 3
              : constraints.maxWidth >= 360
              ? 2
              : 1;
          const gap = 16.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: 14,
            children: [
              for (final (icon, label, value) in items)
                SizedBox(
                  width: width,
                  child: _InfoItem(icon: icon, label: label, value: value),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 17,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                hasValue ? value! : '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasValue ? null : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BookDescriptionCard extends StatelessWidget {
  const BookDescriptionCard({required this.book, super.key});

  final LibraryBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = book.description ?? '';
    return BookSectionCard(
      title: 'Description & keywords',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description.isEmpty ? 'No description added.' : description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: description.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          if (book.keywords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final keyword in book.keywords)
                  Chip(
                    label: Text(keyword),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
