import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show textSearchSupported;
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_card.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_dialog.dart';
import 'package:school_library/src/ui/incidents/widgets/incident_empty_states.dart';
import 'package:school_library/src/ui/incidents/widgets/incidents_table.dart';

/// Manage lost and damaged book incidents (FRS 11.14).
class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<LibraryProvider>().incidentSearch,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadIncidents(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String value) {
    context.read<LibraryProvider>()
      ..incidentStatus = value == 'all' ? null : value
      ..loadIncidents();
  }

  void _search(String value) {
    context.read<LibraryProvider>()
      ..incidentSearch = value.trim()
      ..loadIncidents();
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<LibraryProvider>().clearIncidentFilters();
  }

  Future<void> _open(LibraryIncident incident) async {
    await IncidentDialog.show(context, incident);
    if (mounted) {
      await context.read<LibraryProvider>().loadIncidents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final pager = libraryProvider.incidents;
    final status = libraryProvider.incidentStatus ?? 'all';
    return Scaffold(
      appBar: AppBar(title: const Text('Lost & Damaged')),
      body: context.isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: IncidentsTable(onOpen: _open),
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
                              selected: {status},
                              onSelectionChanged: (values) =>
                                  _onStatusChanged(values.first),
                            ),
                          ),
                        ),
                        if (textSearchSupported) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Title, member or adm. no.',
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
                                suffixIcon:
                                    libraryProvider.incidentSearch.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          _search('');
                                        },
                                      )
                                    : null,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _search,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: pager.loading && pager.items.isEmpty
                        ? const IcueSkeletonCardList()
                        : pager.items.isEmpty
                        ? (libraryProvider.incidentSearch.isNotEmpty ||
                                  libraryProvider.incidentType != null
                              ? IncidentNoResultsState(
                                  searchQuery: libraryProvider.incidentSearch,
                                  onClear: _clearFilters,
                                )
                              : IncidentInitialEmptyState(status: status))
                        : RefreshIndicator(
                            onRefresh: libraryProvider.loadIncidents,
                            child: IcueAdaptiveCardList(
                              itemCount: pager.items.length,
                              footer: IcueLoadMoreFooter.of(pager),
                              itemBuilder: (context, index) => IncidentCard(
                                incident: pager.items[index],
                                onTap: () => _open(pager.items[index]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
