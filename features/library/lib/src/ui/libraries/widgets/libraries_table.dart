import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/add_library_dialog.dart';

/// Wide-screen libraries list: an [IcueClientTable] over the loaded libraries.
class LibrariesTable extends StatelessWidget {
  const LibrariesTable({
    required this.libraries,
    required this.onToggleActive,
    super.key,
  });

  final List<SchoolLibrary> libraries;
  final void Function(SchoolLibrary library) onToggleActive;

  @override
  Widget build(BuildContext context) {
    final campusIds = {
      for (final library in libraries) library.campusId,
    }.toList()..sort();

    return IcueClientTable<SchoolLibrary>(
      title: 'Libraries',
      items: libraries,
      rowKey: (library) => library.id,
      rowLabel: (library) => library.name,
      searchHint: 'Search name or location...',
      searchText: (library) => '${library.name} ${library.location ?? ''}',
      onRowTap: (library) => AddLibraryDialog.show(context, library: library),
      primaryAction: IcueTableAction(
        label: 'Library',
        icon: Icons.add_rounded,
        onPressed: () => AddLibraryDialog.show(context),
      ),
      emptyTitle: 'No libraries yet',
      emptyMessage: 'Add a library to start managing books.',
      emptyAction: IcueTableAction(
        label: 'Add library',
        icon: Icons.add_rounded,
        onPressed: () => AddLibraryDialog.show(context),
      ),
      filters: [
        IcueClientFilter<SchoolLibrary>(
          id: 'campus',
          label: 'Campus',
          options: [
            for (final campusId in campusIds)
              IcueTableFilterOption('$campusId', 'Campus $campusId'),
          ],
          matches: (library, optionId) => '${library.campusId}' == optionId,
        ),
        IcueClientFilter<SchoolLibrary>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('active', 'Active'),
            IcueTableFilterOption('inactive', 'Inactive'),
          ],
          matches: (library, optionId) =>
              (optionId == 'active') == library.active,
        ),
      ],
      rowActions: (library) => [
        IcueTableRowAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          inline: true,
          onPressed: (row) => AddLibraryDialog.show(context, library: row),
        ),
        IcueTableRowAction(
          label: library.active ? 'Deactivate' : 'Activate',
          icon: library.active
              ? Icons.block_outlined
              : Icons.check_circle_outline_rounded,
          inline: true,
          onPressed: onToggleActive,
        ),
      ],
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Library',
          flex: 3,
          minWidth: 200,
          sortable: true,
          comparator: (library) => library.name.toLowerCase(),
          hideable: false,
          cellBuilder: (context, library) => IcueTableCellText(
            library.name,
            leading: library.active ? null : const IcueInactiveBadge(),
          ),
        ),
        IcueTableColumn(
          id: 'campus',
          label: 'Campus',
          sortable: true,
          comparator: (library) => library.campusId,
          cellBuilder: (context, library) => IcueTableCellText(
            'Campus ${library.campusId}',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'location',
          label: 'Location',
          flex: 2,
          cellBuilder: (context, library) => IcueTableCellText(
            library.location ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'hours',
          label: 'Hours',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, library) => IcueTableCellText(
            library.hours ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
      ],
    );
  }
}
