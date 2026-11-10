import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Wide-screen lost and damaged incidents as an [IcueClientTable]. The status
/// filter reloads server data, so the page owns it.
class IncidentsTable extends StatelessWidget {
  const IncidentsTable({
    required this.incidents,
    required this.loading,
    required this.status,
    required this.onStatusChanged,
    required this.onOpen,
    required this.onReport,
    super.key,
  });

  final List<LibraryIncident> incidents;
  final bool loading;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final void Function(LibraryIncident incident) onOpen;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return IcueClientTable<LibraryIncident>(
      title: 'Lost & damaged',
      items: incidents,
      rowKey: (incident) => incident.id,
      rowLabel: (incident) => incident.incidentNumber,
      status: IcueTableStatus.of(failed: false, loading: loading),
      onRowTap: onOpen,
      searchHint: 'Search copy, member, or incident #...',
      searchText: (incident) =>
          '${incident.barcode} ${incident.memberLabel ?? ''} '
          '${incident.incidentNumber}',
      initialSort: const IcueTableSort('reported', ascending: false),
      externalFilters: [
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('open', 'Open'),
            IcueTableFilterOption('resolved', 'Resolved'),
          ],
          value: status == 'all' ? null : status,
          onChanged: (value) => onStatusChanged(value ?? 'all'),
        ),
      ],
      externalFiltersActive: status != 'all',
      onClearExternalFilters: () => onStatusChanged('all'),
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
          sortable: true,
          comparator: (incident) => incident.barcode,
          cellBuilder: (context, incident) =>
              IcueTableCellText(incident.barcode),
        ),
        IcueTableColumn(
          id: 'member',
          label: 'Member',
          flex: 3,
          sortable: true,
          comparator: (incident) => incident.memberLabel ?? '',
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
          sortable: true,
          comparator: (incident) => incident.reportedDate,
          cellBuilder: (context, incident) => IcueTableCellText(
            incident.reportedDate.toDisplayDay(),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'charge',
          label: 'Charge',
          sortable: true,
          comparator: (incident) => incident.charge,
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
