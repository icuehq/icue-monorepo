import 'dart:async';

import 'package:core_ui/src/connectivity/connectivity_service.dart';
import 'package:flutter/material.dart';

/// Wrap the app with it via `MaterialApp.builder`:
/// `builder: (_, child) => ConnectivityBanner(service: s, child: child!)`.
/// Shows a red strip while offline and a brief green one when back online.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({
    required this.service,
    required this.child,
    super.key,
  });

  final ConnectivityService service;
  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _showRestored = false;
  bool _wasOnline = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _wasOnline = widget.service.isOnline;
    widget.service.addListener(_onChange);
  }

  void _onChange() {
    final online = widget.service.isOnline;
    _hideTimer?.cancel();
    if (online && !_wasOnline) {
      _showRestored = true;
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showRestored = false);
      });
    } else {
      _showRestored = false;
    }
    _wasOnline = online;
    setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.service.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = !widget.service.isOnline;
    final visible = offline || _showRestored;
    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: offline
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            offline ? Icons.wifi_off : Icons.wifi,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            offline ? 'No internet connection' : 'Back online',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
