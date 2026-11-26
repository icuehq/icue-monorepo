import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icue_webview/icue_webview.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:school_connect/src/providers/events_provider.dart';
import 'package:school_connect/src/ui/routing/school_connect_router.dart';
import 'package:school_connect/src/ui/widgets/event_list_item.dart';

/// Events the parent can book; each opens the school's booking page.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<EventsProvider>().loadEvents(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<EventsProvider>();
    final bar = IcueContextBar(
      label: context.watch<ParentAuthProvider>().selectedStudent?.name,
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.events),
        bottom: bar,
        actions: [
          IconButton(
            onPressed: () =>
                context.push(SchoolConnectRoutes.paymentHistoryPath),
            icon: const Icon(Icons.payment_outlined),
          ),
        ],
      ),
      body: IcueSheetBody(
        loading: provider.loading,
        hasData: provider.events.isNotEmpty,
        emptyTitle: l10n.noDataFound,
        child: ListView.separated(
          itemCount: provider.events.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final event = provider.events[index];
            return EventListItem(
              event: event,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => IcueWebViewPage(
                    url: event.link,
                    title: event.name,
                    bottom: bar,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
