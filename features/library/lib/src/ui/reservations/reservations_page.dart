import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/circulation_tabs.dart';
import 'package:school_library/src/ui/reservations/widgets/reservation_card.dart';
import 'package:school_library/src/ui/reservations/widgets/reservation_dialog.dart';
import 'package:school_library/src/ui/reservations/widgets/reservation_empty_states.dart';

/// Manage book reservations and queue (FRS 11.12).
class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final _searchController = TextEditingController();
  String _status = 'waiting';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadReservations(status: _status),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String value) {
    setState(() => _status = value);
    context.read<LibraryProvider>().loadReservations(status: value);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  int? _queuePosition(
    LibraryReservation reservation,
    List<LibraryReservation> reservations,
  ) {
    if (reservation.status != 'waiting') return null;
    return reservations
            .take(reservations.indexOf(reservation))
            .where(
              (other) =>
                  other.catalogueId == reservation.catalogueId &&
                  other.libraryId == reservation.libraryId,
            )
            .length +
        1;
  }

  Future<void> _cancel(LibraryReservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel reservation'),
        content: Text(
          'Cancel reservation ${reservation.number} for "${reservation.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final libraryProvider = context.read<LibraryProvider>();
    final success = await libraryProvider.cancelReservation(reservation.id);
    if (!mounted) return;
    showMessage(
      context,
      success
          ? 'Reservation cancelled'
          : libraryProvider.errorMessage ?? 'Could not cancel',
    );
  }

  Future<void> _openCreateReservation() async {
    await ReservationDialog.show(context);
    if (mounted) {
      await context.read<LibraryProvider>().loadReservations(status: _status);
    }
  }

  Widget _statusPill(BuildContext context, LibraryReservation reservation) {
    final theme = Theme.of(context);
    final (color, background) = switch (reservation.status) {
      'ready' => (Colors.green.shade700, Colors.green.withValues(alpha: 0.12)),
      'waiting' => (
        Colors.orange.shade800,
        Colors.orange.withValues(alpha: 0.12),
      ),
      'fulfilled' => (
        theme.colorScheme.primary,
        theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
      'expired' => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      ),
      _ => (Colors.grey.shade700, Colors.grey.withValues(alpha: 0.12)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        reservationStatusLabel(reservation.status),
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
    final allReservations = libraryProvider.reservations;

    final filteredReservations = allReservations.where((reservation) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = reservation.title.toLowerCase().contains(query);
        final matchMember = reservation.memberLabel.toLowerCase().contains(
          query,
        );
        final matchNumber = reservation.number.toLowerCase().contains(query);
        return matchTitle || matchMember || matchNumber;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Circulation'),
        actions: [
          IconButton(
            tooltip: 'Refresh reservations',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => libraryProvider.loadReservations(status: _status),
          ),
        ],
        bottom: CirculationTabBar(activeTab: CirculationTab.reservations),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateReservation,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Reserve'),
      ),
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
                          ButtonSegment(
                            value: 'waiting',
                            label: Text('Waiting'),
                          ),
                          ButtonSegment(value: 'ready', label: Text('Ready')),
                          ButtonSegment(
                            value: 'fulfilled',
                            label: Text('Fulfilled'),
                          ),
                          ButtonSegment(
                            value: 'cancelled',
                            label: Text('Cancelled'),
                          ),
                          ButtonSegment(
                            value: 'expired',
                            label: Text('Expired'),
                          ),
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
                        hintText: 'Search title, member…',
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
              child:
                  libraryProvider.reservationsLoading && allReservations.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredReservations.isEmpty
                  ? (allReservations.isEmpty
                        ? ReservationInitialEmptyState(
                            status: _status,
                            onReserve: _openCreateReservation,
                          )
                        : ReservationNoResultsState(
                            searchQuery: _searchQuery,
                            onClear: _clearSearch,
                          ))
                  : RefreshIndicator(
                      onRefresh: () =>
                          libraryProvider.loadReservations(status: _status),
                      child: AdaptiveList<LibraryReservation>(
                        items: filteredReservations,
                        columns: [
                          AdaptiveColumn(
                            label: 'Title',
                            flex: 3,
                            cell: (context, reservation) => Text(
                              reservation.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          AdaptiveColumn(
                            label: 'Member',
                            flex: 2,
                            cell: (context, reservation) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  reservation.memberType == 'teacher'
                                      ? Icons.person_outline_rounded
                                      : Icons.school_outlined,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    reservation.memberLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdaptiveColumn.text(
                            'Reservation #',
                            (reservation) => reservation.number,
                          ),
                          AdaptiveColumn(
                            label: 'Position / Hold',
                            flex: 2,
                            cell: (context, reservation) {
                              if (reservation.status == 'waiting') {
                                final position = _queuePosition(
                                  reservation,
                                  allReservations,
                                );
                                return Text(
                                  position != null
                                      ? 'Queue position #$position'
                                      : 'Waiting',
                                );
                              }
                              if (reservation.status == 'ready' &&
                                  reservation.holdUntil != null) {
                                return Text(
                                  'Hold until ${reservation.holdUntil!.toDisplayDay()}',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }
                              if (reservation.status == 'fulfilled' &&
                                  reservation.fulfilledCopyId != null) {
                                return Text(
                                  'Copy ${reservation.fulfilledCopyId}',
                                );
                              }
                              return const Text('—');
                            },
                          ),
                          AdaptiveColumn(
                            label: 'Status',
                            cell: (context, reservation) =>
                                _statusPill(context, reservation),
                          ),
                          AdaptiveColumn(
                            label: '',
                            cell: (context, reservation) => reservation.isLive
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                    ),
                                    tooltip: 'Cancel reservation',
                                    onPressed: () => _cancel(reservation),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                        cardBuilder: (context, reservation) => ReservationCard(
                          reservation: reservation,
                          queuePosition: _queuePosition(
                            reservation,
                            allReservations,
                          ),
                          onCancel: reservation.isLive
                              ? () => _cancel(reservation)
                              : null,
                        ),
                        footer: libraryProvider.hasMoreReservations
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: TextButton(
                                    onPressed:
                                        libraryProvider.reservationsLoading
                                        ? null
                                        : () => libraryProvider
                                              .loadReservations(more: true),
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
