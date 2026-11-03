import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/widgets/reservation_sheet.dart';

/// Manage book reservations and queue (FRS 11.12).
class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  String _status = 'waiting';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadReservations(status: _status),
    );
  }

  void _onStatusChanged(String value) {
    setState(() => _status = value);
    context.read<LibraryProvider>().loadReservations(status: value);
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
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final libraryProvider = context.read<LibraryProvider>();
    final ok = await libraryProvider.cancelReservation(reservation.id);
    if (!mounted) return;
    showMessage(
      context,
      ok
          ? 'Reservation cancelled'
          : libraryProvider.errorMessage ?? 'Could not cancel',
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reservations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ReservationSheet.show(context);
          if (mounted) {
            await libraryProvider.loadReservations(status: _status);
          }
        },
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Reserve'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'waiting', label: Text('Waiting')),
                ButtonSegment(value: 'ready', label: Text('Ready')),
                ButtonSegment(value: 'fulfilled', label: Text('Fulfilled')),
                ButtonSegment(value: 'cancelled', label: Text('Cancelled')),
                ButtonSegment(value: 'expired', label: Text('Expired')),
              ],
              selected: {_status},
              onSelectionChanged: (values) => _onStatusChanged(values.first),
            ),
          ),
          Expanded(
            child: libraryProvider.reservations.isEmpty
                ? Center(
                    child: Text(
                      libraryProvider.reservationsLoading
                          ? 'Loading…'
                          : libraryProvider.errorMessage ??
                                'No $_status reservations',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        libraryProvider.reservations.length +
                        (libraryProvider.hasMoreReservations ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= libraryProvider.reservations.length) {
                        return Center(
                          child: TextButton(
                            onPressed: libraryProvider.reservationsLoading
                                ? null
                                : () => libraryProvider.loadReservations(
                                    more: true,
                                  ),
                            child: const Text('Load more'),
                          ),
                        );
                      }
                      final currentReservation =
                          libraryProvider.reservations[index];
                      // Position within the same title and library; the list is oldest first.
                      final position =
                          libraryProvider.reservations
                              .take(index)
                              .where(
                                (reservation) =>
                                    reservation.catalogueId ==
                                        currentReservation.catalogueId &&
                                    reservation.libraryId ==
                                        currentReservation.libraryId,
                              )
                              .length +
                          1;
                      final subtitle = switch (currentReservation.status) {
                        'waiting' =>
                          'Queue: #$position · ${currentReservation.number}',
                        'ready' =>
                          'Held: ${currentReservation.heldCopyId ?? '-'} · Hold until ${currentReservation.holdUntil ?? '-'} · ${currentReservation.number}',
                        'fulfilled' =>
                          'Fulfilled: copy ${currentReservation.fulfilledCopyId ?? '-'} · ${currentReservation.number}',
                        _ =>
                          '${reservationStatusLabel(currentReservation.status)} · ${currentReservation.number}',
                      };
                      return ListTile(
                        title: Text(
                          '${currentReservation.title} · ${currentReservation.memberLabel}',
                        ),
                        subtitle: Text(subtitle),
                        trailing: currentReservation.isLive
                            ? IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                tooltip: 'Cancel reservation',
                                onPressed: () => _cancel(currentReservation),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
