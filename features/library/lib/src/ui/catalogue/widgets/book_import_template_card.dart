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
              IcueStatusPill(
                label: '$column *',
                color: Theme.of(context).colorScheme.primary,
              ),
            for (final column in _optionalColumns)
              IcueStatusPill(
                label: column,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
