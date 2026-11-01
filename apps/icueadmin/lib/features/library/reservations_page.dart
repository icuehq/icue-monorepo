import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/reservation_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

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

  void _onStatusChanged(String s) {
    setState(() => _status = s);
    context.read<LibraryProvider>().loadReservations(status: s);
  }

  Future<void> _cancel(LibReservation r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation'),
        content: Text('Cancel reservation ${r.number} for "${r.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final p = context.read<LibraryProvider>();
    final ok = await p.cancelReservation(r.id);
    if (!mounted) return;
    invSnack(
      context,
      ok ? 'Reservation cancelled' : p.errorMessage ?? 'Could not cancel',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reservations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await ReservationSheet.show(context);
          if (mounted) {
            await p.loadReservations(status: _status);
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
              onSelectionChanged: (s) => _onStatusChanged(s.first),
            ),
          ),
          Expanded(
            child: p.reservations.isEmpty
                ? Center(
                    child: Text(
                      p.reservationsLoading
                          ? 'Loading…'
                          : p.errorMessage ?? 'No $_status reservations',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        p.reservations.length + (p.hasMoreReservations ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= p.reservations.length) {
                        return Center(
                          child: TextButton(
                            onPressed: p.reservationsLoading
                                ? null
                                : () => p.loadReservations(more: true),
                            child: const Text('Load more'),
                          ),
                        );
                      }
                      final r = p.reservations[index];
                      // Position within the same title and library; the list is oldest first.
                      final position =
                          p.reservations
                              .take(index)
                              .where(
                                (o) =>
                                    o.catalogueId == r.catalogueId &&
                                    o.libraryId == r.libraryId,
                              )
                              .length +
                          1;
                      final subtitle = switch (r.status) {
                        'waiting' => 'Queue: #$position · ${r.number}',
                        'ready' =>
                          'Held: ${r.heldCopyId ?? '-'} · Hold until ${r.holdUntil ?? '-'} · ${r.number}',
                        'fulfilled' =>
                          'Fulfilled: copy ${r.fulfilledCopyId ?? '-'} · ${r.number}',
                        _ =>
                          '${reservationStatusLabel(r.status)} · ${r.number}',
                      };
                      return ListTile(
                        title: Text('${r.title} · ${r.memberLabel}'),
                        subtitle: Text(subtitle),
                        trailing: r.isLive
                            ? IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                tooltip: 'Cancel reservation',
                                onPressed: () => _cancel(r),
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
