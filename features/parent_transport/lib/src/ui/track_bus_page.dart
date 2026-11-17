import 'dart:async';

import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/src/providers/parent_tracking_provider.dart';
import 'package:parent_transport/src/ui/widgets/live_map.dart';
import 'package:parent_transport/src/ui/widgets/route_notifications_dialog.dart';
import 'package:parent_transport/src/ui/widgets/tracking_info_card.dart';
import 'package:parent_transport/src/ui/widgets/tracking_message_dialog.dart';
import 'package:provider/provider.dart';

const _pollInterval = Duration(seconds: 5);

/// Live bus map of the selected student; polls every 5 s while in the foreground.
class TrackBusPage extends StatefulWidget {
  const TrackBusPage({super.key});

  @override
  State<TrackBusPage> createState() => _TrackBusPageState();
}

class _TrackBusPageState extends State<TrackBusPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _messageShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  void _start() {
    if (!mounted) return;
    final provider = context.read<ParentTrackingProvider>();
    _timer?.cancel();
    provider
      ..reset()
      ..refresh();
    _timer = Timer.periodic(
      _pollInterval,
      (_) => provider.refresh(polling: true),
    );
  }

  String? _messageFor(ParentTrackingProvider provider) {
    final l10n = ParentLocalizations.of(context);
    return switch (provider.status) {
      TrackingStatus.notStarted => l10n.routeNotStarted,
      TrackingStatus.completed => l10n.routeCompleted,
      TrackingStatus.unavailable =>
        provider.message ?? l10n.trackingUnavailable,
      _ => null,
    };
  }

  void _showMessageOnce(ParentTrackingProvider provider) {
    final message = _messageFor(provider);
    if (message == null || _messageShown) return;
    _messageShown = true;
    _timer?.cancel();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TrackingMessageDialog(message: message),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParentTrackingProvider>();
    final auth = context.watch<ParentAuthProvider>();
    final student = auth.selectedStudent;
    final l10n = ParentLocalizations.of(context);
    _showMessageOnce(provider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.liveTracking),
        bottom: IcueContextBar(label: student?.name),
        actions: [
          if (provider.isLive && (student?.showNotification ?? false))
            _NotificationsButton(
              unread: provider.liveData?.msgAvailable ?? false,
              routeTrackId: provider.routeTrackId,
            ),
        ],
      ),
      bottomNavigationBar:
          provider.isLive &&
              student != null &&
              (student.showRoutePanel ?? false)
          ? TrackingInfoCard(
              pickPoint: student.pickPoint ?? '',
              routeNo: provider.routeNo,
              showEta: student.showEta ?? false,
              etaValue: provider.liveData?.etaValue,
              driverMobile: (student.showContactNo ?? false)
                  ? provider.driverMobile
                  : null,
            )
          : null,
      body: IcueSheetBody(
        loading: student == null || provider.liveData == null,
        child: student == null
            ? const SizedBox.shrink()
            : LiveMap(data: provider.liveData, student: student),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({
    required this.unread,
    required this.routeTrackId,
  });

  final bool unread;
  final int routeTrackId;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topRight,
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_none_outlined, size: 40),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => RouteNotificationsDialog(routeTrackId: routeTrackId),
        ),
      ),
      Positioned(
        left: 30,
        top: 10,
        child: CircleAvatar(
          radius: 7,
          backgroundColor: unread ? Colors.green : Colors.red,
        ),
      ),
    ],
  );
}
