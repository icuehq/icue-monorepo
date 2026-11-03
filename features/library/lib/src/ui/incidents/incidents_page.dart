import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_report_sheet.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_sheet.dart';

/// Manage lost and damaged book incidents (FRS 11.14).
class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  String _status = 'open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadIncidents(status: _status),
    );
  }

  void _onStatusChanged(String value) {
    setState(() => _status = value);
    context.read<LibraryProvider>().loadIncidents(status: value);
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canOperate = libraryProvider.access.can(
      'library.circulation.operate',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lost & Damaged Books')),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: () async {
                await IncidentReportSheet.show(context);
                if (mounted) {
                  await libraryProvider.loadIncidents(status: _status);
                }
              },
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report incident'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Open')),
                ButtonSegment(value: 'resolved', label: Text('Resolved')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_status},
              onSelectionChanged: (values) => _onStatusChanged(values.first),
            ),
          ),
          Expanded(
            child: libraryProvider.incidents.isEmpty
                ? Center(
                    child: Text(
                      libraryProvider.incidentsLoading
                          ? 'Loading…'
                          : libraryProvider.errorMessage ??
                                'No $_status incidents',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        libraryProvider.incidents.length +
                        (libraryProvider.hasMoreIncidents ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= libraryProvider.incidents.length) {
                        return Center(
                          child: TextButton(
                            onPressed: libraryProvider.incidentsLoading
                                ? null
                                : () =>
                                      libraryProvider.loadIncidents(more: true),
                            child: const Text('Load more'),
                          ),
                        );
                      }
                      final incident = libraryProvider.incidents[index];
                      final subtitle =
                          '${humanizeStatus(incident.type)}${incident.severity != null ? ' (${humanizeStatus(incident.severity)})' : ''}'
                          '${incident.memberLabel != null ? ' · ${incident.memberLabel}' : ''}'
                          ' · ${incident.reportedDate}';
                      return ListTile(
                        title: Text(
                          '${incident.incidentNumber} · ${incident.accessionNumber}',
                        ),
                        subtitle: Text(subtitle),
                        trailing: Chip(
                          label: Text(humanizeStatus(incident.status)),
                          backgroundColor: incident.isOpen
                              ? Theme.of(context).colorScheme.errorContainer
                              : null,
                        ),
                        onTap: () async {
                          await IncidentSheet.show(context, incident);
                          if (mounted) {
                            await libraryProvider.loadIncidents(
                              status: _status,
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
