import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_card.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_dialog.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_empty_states.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_report_dialog.dart';
import 'package:school_library/src/ui/incidents/widgets/incidents_table.dart';

/// Manage lost and damaged book incidents (FRS 11.14).
class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  final _searchController = TextEditingController();
  String _status = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadIncidents(status: _status),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String value) {
    setState(() => _status = value);
    context.read<LibraryProvider>().loadIncidents(status: value);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _open(LibraryIncident incident) async {
    await IncidentDialog.show(context, incident);
    if (mounted) {
      await context.read<LibraryProvider>().loadIncidents(status: _status);
    }
  }

  Future<void> _openReportIncident() async {
    await IncidentReportDialog.show(context);
    if (mounted) {
      await context.read<LibraryProvider>().loadIncidents(status: _status);
    }
  }

  Widget _statusPill(BuildContext context, LibraryIncident incident) {
    final theme = Theme.of(context);
    final (color, background) = incident.isOpen
        ? (
            theme.colorScheme.error,
            theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          )
        : (Colors.green.shade700, Colors.green.withValues(alpha: 0.12));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        humanizeStatus(incident.status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final allIncidents = libraryProvider.incidents;

    final filteredIncidents = allIncidents.where((incident) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchAccession = incident.barcode.toLowerCase().contains(query);
        final matchIncident = incident.incidentNumber.toLowerCase().contains(
          query,
        );
        final matchMember =
            incident.memberLabel?.toLowerCase().contains(query) ?? false;
        return matchAccession || matchIncident || matchMember;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Lost & Damaged')),
      floatingActionButton: context.isWide
          ? null
          : FloatingActionButton.extended(
              onPressed: _openReportIncident,
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report incident'),
            ),
      body: context.isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: IncidentsTable(
                      incidents: allIncidents,
                      loading:
                          libraryProvider.incidentsLoading &&
                          allIncidents.isEmpty,
                      status: _status,
                      onStatusChanged: _onStatusChanged,
                      onOpen: _open,
                      onReport: _openReportIncident,
                    ),
                  ),
                  if (libraryProvider.hasMoreIncidents)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IcueButton(
                        label: 'Load more',
                        onPressed: libraryProvider.incidentsLoading
                            ? null
                            : () => libraryProvider.loadIncidents(more: true),
                        variant: IcueButtonVariant.ghost,
                      ),
                    ),
                ],
              ),
            )
          : IcueCenteredBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'open',
                                  label: Text('Open'),
                                ),
                                ButtonSegment(
                                  value: 'resolved',
                                  label: Text('Resolved'),
                                ),
                                ButtonSegment(value: 'all', label: Text('All')),
                              ],
                              selected: {_status},
                              onSelectionChanged: (values) =>
                                  _onStatusChanged(values.first),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search copy, member…',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value.trim()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        libraryProvider.incidentsLoading && allIncidents.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredIncidents.isEmpty
                        ? (allIncidents.isEmpty
                              ? IncidentInitialEmptyState(
                                  status: _status,
                                  onReport: _openReportIncident,
                                )
                              : IncidentNoResultsState(
                                  searchQuery: _searchQuery,
                                  onClear: _clearSearch,
                                ))
                        : RefreshIndicator(
                            onRefresh: () =>
                                libraryProvider.loadIncidents(status: _status),
                            child: IcueAdaptiveList<LibraryIncident>(
                              items: filteredIncidents,
                              onTap: _open,
                              columns: [
                                IcueAdaptiveColumn(
                                  label: 'Copy',
                                  flex: 2,
                                  cell: (context, incident) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_2_rounded,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        incident.barcode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IcueAdaptiveColumn(
                                  label: 'Member',
                                  flex: 3,
                                  cell: (context, incident) {
                                    final member = incident.memberLabel;
                                    if (member == null) {
                                      return const Text(
                                        'In stock',
                                        style: TextStyle(color: Colors.grey),
                                      );
                                    }
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          incident.memberType == 'teacher'
                                              ? Icons.person_outline_rounded
                                              : Icons.school_outlined,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            member,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                IcueAdaptiveColumn.text(
                                  'Incident #',
                                  (incident) => incident.incidentNumber,
                                ),
                                IcueAdaptiveColumn(
                                  label: 'Type',
                                  flex: 2,
                                  cell: (context, incident) => Text(
                                    '${humanizeStatus(incident.type)}'
                                    '${incident.severity != null ? ' (${humanizeStatus(incident.severity!)})' : ''}',
                                  ),
                                ),
                                IcueAdaptiveColumn.text(
                                  'Reported',
                                  (incident) =>
                                      incident.reportedDate.toDisplayDay(),
                                ),
                                IcueAdaptiveColumn(
                                  label: 'Charge',
                                  cell: (context, incident) => Text(
                                    incident.charge > 0
                                        ? incident.charge.toRupees()
                                        : '—',
                                    style: TextStyle(
                                      color: incident.charge > 0
                                          ? theme.colorScheme.error
                                          : null,
                                      fontWeight: incident.charge > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                IcueAdaptiveColumn(
                                  label: 'Status',
                                  cell: (context, incident) =>
                                      _statusPill(context, incident),
                                ),
                              ],
                              cardBuilder: (context, incident) => IncidentCard(
                                incident: incident,
                                onTap: () => _open(incident),
                              ),
                              footer: libraryProvider.hasMoreIncidents
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: IcueButton(
                                          label: 'Load more',
                                          onPressed:
                                              libraryProvider.incidentsLoading
                                              ? null
                                              : () => libraryProvider
                                                    .loadIncidents(more: true),
                                          variant: IcueButtonVariant.ghost,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
