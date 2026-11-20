import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';

import 'package:icue_sdk/icue_sdk.dart';

/// Controller and presenter for displaying in-app notification banners.
class IcueNotificationOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Displays an in-app notification banner over the active navigator overlay.
  ///
  /// If [duration] is not provided or is [Duration.zero], the banner persists on screen
  /// until the user taps it or manually closes it via the close button / swipe gesture.
  static void show({
    BuildContext? context,
    OverlayState? overlayState,
    required String title,
    required String body,
    required VoidCallback onTap,
    Duration? duration,
  }) {
    // Dismiss any existing banner first
    dismiss();

    final overlay = overlayState ??
        (context != null
            ? (Navigator.maybeOf(context)?.overlay ??
                Overlay.maybeOf(context, rootOverlay: true))
            : null) ??
        IcueSdk.overlayState;

    if (overlay == null) {
      log(
        'iCue SDK: Cannot show in-app banner: No active Overlay found. Make sure MaterialApp has navigatorKey: IcueSdk.navigatorKey or IcueSdk.setNavigatorKey() was called.',
      );
      return;
    }

    final entryKey = GlobalKey<_InAppNotificationBannerWidgetState>();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _InAppNotificationBannerWidget(
        key: entryKey,
        title: title,
        body: body,
        onTap: () {
          dismiss();
          onTap();
        },
        onDismiss: _removeEntry,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    if (duration != null && duration > Duration.zero) {
      _dismissTimer = Timer(duration, () {
        if (entryKey.currentState != null && entryKey.currentState!.mounted) {
          entryKey.currentState!.animateDismiss();
        } else {
          dismiss();
        }
      });
    }
  }

  static void _removeEntry() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null) {
      try {
        if (_currentEntry!.mounted) {
          _currentEntry!.remove();
        }
      } catch (_) {}
      _currentEntry = null;
    }
  }

  /// Dismisses the currently displayed notification banner, if any.
  static void dismiss() {
    _removeEntry();
  }
}

class _InAppNotificationBannerWidget extends StatefulWidget {
  const _InAppNotificationBannerWidget({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_InAppNotificationBannerWidget> createState() =>
      _InAppNotificationBannerWidgetState();
}

class _InAppNotificationBannerWidgetState
    extends State<_InAppNotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  Future<void> animateDismiss() async {
    if (!mounted) return;
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.maybeOf(context);
    final topPadding = mediaQuery?.padding.top ?? 0.0;

    final backgroundColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final iconBgColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF);
    final iconColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Positioned(
      top: topPadding + 8.0,
      left: 16.0,
      right: 16.0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  // Swiped up -> dismiss
                  animateDismiss();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 80 : 35),
                      blurRadius: 18.0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: borderColor,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40.0,
                      height: 40.0,
                      margin: const EdgeInsets.only(top: 2.0),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        color: iconColor,
                        size: 22.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ) ??
                                TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.body.isNotEmpty) ...[
                            const SizedBox(height: 3.0),
                            Text(
                              widget.body,
                              style: theme.textTheme.bodySmall?.copyWith(
                                    color: bodyColor,
                                    height: 1.3,
                                  ) ??
                                  TextStyle(
                                    fontSize: 12.0,
                                    color: bodyColor,
                                    height: 1.3,
                                  ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18.0,
                        color: bodyColor,
                      ),
                      onPressed: animateDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
