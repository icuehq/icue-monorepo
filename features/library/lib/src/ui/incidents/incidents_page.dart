import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_card.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_empty_states.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_report_sheet.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_sheet.dart';

/// Manage lost and damaged book incidents (FRS 11.14).
class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  final _searchController = TextEditingController();
  String _status = 'open';
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
    await IncidentSheet.show(context, incident);
    if (mounted) {
      await context.read<LibraryProvider>().loadIncidents(status: _status);
    }
  }

  Future<void> _openReportIncident() async {
    await IncidentReportSheet.show(context);
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
    final canOperate = libraryProvider.access.can(
      'library.circulation.operate',
    );
    final theme = Theme.of(context);
    final allIncidents = libraryProvider.incidents;

    final filteredIncidents = allIncidents.where((incident) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchAccession = incident.accessionNumber.toLowerCase().contains(
          query,
        );
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
      appBar: AppBar(
        title: const Text('Lost & Damaged Books'),
        actions: [
          IconButton(
            tooltip: 'Refresh incidents',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadIncidents(status: _status),
          ),
        ],
      ),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: _openReportIncident,
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report incident'),
            )
          : null,
      body: CenteredBody(
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
                          ButtonSegment(value: 'open', label: Text('Open')),
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
                        fillColor: theme.colorScheme.surfaceContainerHighest
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
              child: libraryProvider.incidentsLoading && allIncidents.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredIncidents.isEmpty
                  ? (allIncidents.isEmpty
                        ? IncidentInitialEmptyState(
                            status: _status,
                            onReport: canOperate ? _openReportIncident : null,
                          )
                        : IncidentNoResultsState(
                            searchQuery: _searchQuery,
                            onClear: _clearSearch,
                          ))
                  : RefreshIndicator(
                      onRefresh: () =>
                          libraryProvider.loadIncidents(status: _status),
                      child: AdaptiveList<LibraryIncident>(
                        items: filteredIncidents,
                        onTap: _open,
                        columns: [
                          AdaptiveColumn(
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
                                  incident.accessionNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdaptiveColumn(
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
                          AdaptiveColumn.text(
                            'Incident #',
                            (incident) => incident.incidentNumber,
                          ),
                          AdaptiveColumn(
                            label: 'Type',
                            flex: 2,
                            cell: (context, incident) => Text(
                              '${humanizeStatus(incident.type)}'
                              '${incident.severity != null ? ' (${humanizeStatus(incident.severity!)})' : ''}',
                            ),
                          ),
                          AdaptiveColumn.text(
                            'Reported',
                            (incident) => incident.reportedDate.toDisplayDay(),
                          ),
                          AdaptiveColumn(
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
                          AdaptiveColumn(
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
                                  child: TextButton(
                                    onPressed: libraryProvider.incidentsLoading
                                        ? null
                                        : () => libraryProvider.loadIncidents(
                                            more: true,
                                          ),
                                    child: const Text('Load more'),
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
