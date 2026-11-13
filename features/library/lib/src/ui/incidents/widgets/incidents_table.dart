import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Wide-screen lost and damaged incidents as an [IcueTable]. Search and every
/// filter are Firestore queries (the provider reloads); pages come from its pager.
class IncidentsTable extends StatelessWidget {
  const IncidentsTable({required this.onOpen, super.key});

  final void Function(LibraryIncident incident) onOpen;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final pager = provider.incidents;

    return IcueTable<LibraryIncident>(
      title: 'Lost & damaged',
      rows: pager.items,
      rowKey: (incident) => incident.id,
      rowLabel: (incident) => incident.id,
      count: pager.total ?? pager.items.length,
      status: IcueTableStatus.pager(pager),
      onRetry: pager.retry,
      pagination: IcueTablePagination.pager(pager),
      onRowTap: onOpen,
      searchHint: 'Incident # or accession no.',
      initialSearch: provider.incidentSearch,
      searchDebounce: const Duration(milliseconds: 400),
      onSearchChanged: (query) {
        provider.incidentSearch = query.trim();
        provider.loadIncidents();
      },
      filters: [
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('open', 'Open'),
            IcueTableFilterOption('resolved', 'Resolved'),
          ],
          value: provider.incidentStatus,
          onChanged: (value) {
            provider
              ..incidentStatus = value
              ..loadIncidents();
          },
        ),
        IcueTableFilter(
          id: 'type',
          label: 'Type',
          options: const [
            IcueTableFilterOption('lost', 'Lost'),
            IcueTableFilterOption('damaged', 'Damaged'),
          ],
          value: provider.incidentType,
          onChanged: (value) {
            provider
              ..incidentType = value
              ..loadIncidents();
          },
        ),
      ],
      isFiltered: provider.incidentsFiltered,
      onClearFilters: provider.clearIncidentFilters,
      emptyTitle: 'No incidents',
      emptyMessage: 'Lost and damaged copies will appear here.',
      columns: [
        IcueTableColumn(
          id: 'book',
          label: 'Book Title',
          flex: 2,
          cellBuilder: (context, incident) =>
              IcueTableCellText(incident.bookTitle ?? incident.barcode),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 2,
          cellBuilder: (context, incident) {
            final classLabel = provider.classLabel(
              incident.memberClassId,
              incident.memberSection,
            );
            return IcueTableCellText(
              incident.memberLabel ?? 'In stock',
              style: IcueTableStyle.of(context).secondary,
              subtitle: classLabel == '-' ? null : classLabel,
            );
          },
        ),
        IcueTableColumn(
          id: 'admission',
          label: 'Admission Number',
          flex: 2,
          hideBelowWidth: 900,
          cellBuilder: (context, incident) => IcueTableCellText(
            incident.admissionNumber ?? '-',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'type',
          label: 'Type',
          flex: 2,
          cellBuilder: (context, incident) => IcueTableCellText(
            humanizeStatus(incident.type) +
                (incident.severity == null
                    ? ''
                    : ' (${humanizeStatus(incident.severity!)})'),
          ),
        ),
        IcueTableColumn(
          id: 'reported',
          label: 'Reported',
          cellBuilder: (context, incident) => IcueTableCellText(
            incident.reportedDate.toDisplayDay(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'charge',
          label: 'Charge',
          cellBuilder: (context, incident) => IcueTableCellText(
            incident.charge > 0 ? incident.charge.toRupees() : '—',
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 160,
          cellBuilder: (context, incident) =>
              LibraryStatusChip(incident.status),
        ),
      ],
    );
  }
}
