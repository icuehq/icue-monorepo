import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icue_sdk/src/models/route_notifications.dart';
import 'package:icue_sdk/src/providers/notifications_provider.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:provider/provider.dart';

class NotificationsDialog extends StatefulWidget {
  const NotificationsDialog({super.key, required this.routeTrackId});

  final int routeTrackId;

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  Timer? _closeTimer;

  @override
  void dispose() {
    _cancelCloseTimer();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fetchDataAndStartTimer(),
    );
  }

  void _fetchDataAndStartTimer() {
    if (!mounted) return;

    final student = context.read<UserProvider>().user;
    if (student != null) {
      context.read<NotificationsProvider>().getNotifications(
            routeTrackId: widget.routeTrackId,
            studentId: student.id,
          );
    }
    _startCloseTimer();
  }

  void _startCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 150,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 150,
      child: Center(
        child: Text(
          'No notifications available.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<Msg> messages) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final isLast = index == messages.length - 1;
        final isFirst = index == 0;
        final msg = messages[index];
        return _NotificationTimelineTile(
          title: msg.msg,
          timestamp: msg.at,
          isFirst: isFirst,
          isLast: isLast,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final messages = provider.msgs.reversed.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        'Notifications History',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
      // The Listener cancels the auto-close timer as soon as the user interacts.
      content: Listener(
        onPointerDown: (_) => _cancelCloseTimer(),
        child: SizedBox(
          // Use double.maxFinite to fill the width of the dialog for responsiveness.
          width: double.maxFinite,
          child: provider.loading
              ? _buildLoadingIndicator()
              : messages.isEmpty
                  ? _buildEmptyState()
                  : _buildTimeline(messages),
        ),
      ),
    );
  }
}

class _NotificationTimelineTile extends StatelessWidget {
  const _NotificationTimelineTile({
    required this.title,
    required this.timestamp,
    required this.isFirst,
    required this.isLast,
  });

  final bool isFirst;
  final bool isLast;
  final String timestamp;
  final String title;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xff66c97f);
    const inactiveColor = Color(0xff989898);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: isFirst ? activeColor : inactiveColor,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: inactiveColor),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2.5, color: inactiveColor))
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ) ??
                        const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timestamp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).hintColor,
                            ) ??
                        const TextStyle(
                          fontSize: 14,
                          color: Color(0xff9b9b9b),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
