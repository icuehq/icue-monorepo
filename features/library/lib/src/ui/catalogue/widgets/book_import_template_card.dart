import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Card explaining the spreadsheet format and offering template downloads.
class BookImportTemplateCard extends StatelessWidget {
  const BookImportTemplateCard({required this.onDownload, super.key});

  final Future<void> Function(String format) onDownload;

  static const _requiredColumns = [
    'Barcode',
    'Title',
    'Authors',
    'Category',
    'Library',
  ];

  static const _optionalColumns = [
    'Shelf',
    'Condition',
    'Price',
    'Purchase Date',
    'Subtitle',
    'Publisher',
    'Edition',
    'Year',
    'Language',
    'Pages',
    'Classes',
    'Keywords',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IcueFormSectionCard(
      title: '1. Download template',
      icon: Icons.download_rounded,
      children: [
        Text(
          'Fill in book details using our official spreadsheet template. '
          'Each row represents one physical copy with its unique barcode. '
          'Copies with matching title, first author, edition, publisher, and year '
          'are automatically grouped into one book catalogue record.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Expected columns',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final column in _requiredColumns)
              _ColumnBadge(label: '$column *', isRequired: true),
            for (final column in _optionalColumns)
              _ColumnBadge(label: column, isRequired: false),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            IcueButton(
              label: 'Excel template (.xlsx)',
              leadingIcon: Icons.table_chart_outlined,
              variant: IcueButtonVariant.outline,
              onPressed: () => onDownload('xlsx'),
            ),
            IcueButton(
              label: 'CSV template (.csv)',
              leadingIcon: Icons.description_outlined,
              variant: IcueButtonVariant.outline,
              onPressed: () => onDownload('csv'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColumnBadge extends StatelessWidget {
  const _ColumnBadge({required this.label, required this.isRequired});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRequired
            ? scheme.primaryContainer.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isRequired
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: isRequired ? FontWeight.w600 : FontWeight.normal,
          color: isRequired ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
