import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/src/providers/route_notifications_provider.dart';
import 'package:provider/provider.dart';
import 'package:timelines_plus/timelines_plus.dart';

/// Timeline of the messages sent during the current bus run, newest first.
class RouteNotificationsDialog extends StatefulWidget {
  const RouteNotificationsDialog({required this.routeTrackId, super.key});

  final int routeTrackId;

  @override
  State<RouteNotificationsDialog> createState() =>
      _RouteNotificationsDialogState();
}

class _RouteNotificationsDialogState extends State<RouteNotificationsDialog> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) =>
          context.read<RouteNotificationsProvider>().load(widget.routeTrackId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteNotificationsProvider>();
    final messages = provider.messages.reversed.toList();
    final l10n = ParentLocalizations.of(context);
    return IcueDialog(
      title: l10n.notificationsHistory,
      icon: Icons.notifications_none_outlined,
      size: IcueDialogSize.large,
      primaryAction: IcueDialogAction(
        label: l10n.close,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      content: provider.loading
          ? const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: FixedTimeline.tileBuilder(
                mainAxisSize: MainAxisSize.min,
                theme: TimelineThemeData(
                  nodePosition: 0,
                  color: const Color(0xFF989898),
                  indicatorTheme: const IndicatorThemeData(
                    position: 0,
                    size: 20,
                  ),
                  connectorTheme: const ConnectorThemeData(thickness: 2.5),
                ),
                builder: TimelineTileBuilder.connected(
                  connectionDirection: ConnectionDirection.before,
                  itemCount: messages.length,
                  contentsBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          messages[index].message,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          messages[index].at,
                          style: const TextStyle(color: Color(0xFF9B9B9B)),
                        ),
                      ],
                    ),
                  ),
                  indicatorBuilder: (_, _) => const DotIndicator(
                    color: Color(0xFF66C97F),
                    child: Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                  connectorBuilder: (_, index, _) => SolidLineConnector(
                    color: index == 0 ? const Color(0xFF66C97F) : null,
                  ),
                ),
              ),
            ),
    );
  }
}
