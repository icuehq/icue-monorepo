import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen lost and damaged incidents as an [IcueTable]. Search and every
/// filter are Firestore queries (the provider reloads); pages come from its pager.
class IncidentsTable extends StatelessWidget {
  const IncidentsTable({
    required this.onOpen,
    required this.onReport,
    super.key,
  });

  final void Function(LibraryIncident incident) onOpen;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final pager = provider.incidents;

    return IcueTable<LibraryIncident>(
      title: 'Lost & damaged',
      rows: pager.items,
      rowKey: (incident) => incident.id,
      rowLabel: (incident) => incident.incidentNumber,
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
      primaryAction: IcueTableAction(
        label: 'Report incident',
        icon: Icons.report_problem_outlined,
        onPressed: onReport,
      ),
      emptyTitle: 'No incidents',
      emptyMessage: 'Lost and damaged copies will appear here.',
      columns: [
        IcueTableColumn(
          id: 'copy',
          label: 'Copy',
          flex: 2,
          cellBuilder: (context, incident) =>
              IcueTableCellText(incident.barcode),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 3,
          cellBuilder: (context, incident) => IcueTableCellText(
            incident.memberLabel ?? 'In stock',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'number',
          label: 'Incident #',
          hideBelowWidth: 900,
          cellBuilder: (context, incident) => IcueTableCellText(
            incident.incidentNumber,
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
          width: 110,
          cellBuilder: (context, incident) =>
              IcueTableCellText(humanizeStatus(incident.status)),
        ),
      ],
    );
  }
}
