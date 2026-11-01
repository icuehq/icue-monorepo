import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/incident_report_sheet.dart';
import 'package:icueadmin/features/library/widgets/incident_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

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

  void _onStatusChanged(String s) {
    setState(() => _status = s);
    context.read<LibraryProvider>().loadIncidents(status: s);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final canOperate = p.access.can('lib.circulation.operate');

    return Scaffold(
      appBar: AppBar(title: const Text('Lost & Damaged Books')),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: () async {
                await IncidentReportSheet.show(context);
                if (mounted) {
                  await p.loadIncidents(status: _status);
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
              onSelectionChanged: (s) => _onStatusChanged(s.first),
            ),
          ),
          Expanded(
            child: p.incidents.isEmpty
                ? Center(
                    child: Text(
                      p.incidentsLoading
                          ? 'Loading…'
                          : p.errorMessage ?? 'No $_status incidents',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        p.incidents.length + (p.hasMoreIncidents ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= p.incidents.length) {
                        return Center(
                          child: TextButton(
                            onPressed: p.incidentsLoading
                                ? null
                                : () => p.loadIncidents(more: true),
                            child: const Text('Load more'),
                          ),
                        );
                      }
                      final inc = p.incidents[index];
                      final subtitle =
                          '${incidentKindLabel(inc.kind)}${inc.severity != null ? ' (${incidentSeverityLabel(inc.severity)})' : ''}'
                          '${inc.memberLabel != null ? ' · ${inc.memberLabel}' : ''}'
                          ' · ${inc.reportedDate}';
                      return ListTile(
                        title: Text(
                          '${inc.incidentNumber} · ${inc.accessionNo}',
                        ),
                        subtitle: Text(subtitle),
                        trailing: Chip(
                          label: Text(incidentStatusLabel(inc.status)),
                          backgroundColor: inc.isOpen
                              ? Theme.of(context).colorScheme.errorContainer
                              : null,
                        ),
                        onTap: () async {
                          await IncidentSheet.show(context, inc);
                          if (mounted) {
                            await p.loadIncidents(status: _status);
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
