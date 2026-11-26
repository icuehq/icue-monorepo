import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:school_connect/src/providers/events_provider.dart';
import 'package:school_connect/src/ui/widgets/event_payment_card.dart';

/// Past event bookings and payments, loaded 10 at a time while scrolling.
class EventPaymentHistoryPage extends StatefulWidget {
  const EventPaymentHistoryPage({super.key});

  @override
  State<EventPaymentHistoryPage> createState() =>
      _EventPaymentHistoryPageState();
}

class _EventPaymentHistoryPageState extends State<EventPaymentHistoryPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<EventsProvider>().loadPayments(),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      context.read<EventsProvider>().loadMorePayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<EventsProvider>();
    final payments = provider.payments;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.eventPaymentsHistory),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadPayments,
        child: provider.loading && payments.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : payments.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: IcueEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.noPaymentRecords,
                      neutral: true,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: payments.length + (provider.hasMorePayments ? 1 : 0),
                itemBuilder: (context, index) => index == payments.length
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : EventPaymentCard(payment: payments[index]),
              ),
      ),
    );
  }
}
