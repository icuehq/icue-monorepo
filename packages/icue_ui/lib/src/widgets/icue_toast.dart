import 'dart:async';

import 'package:flutter/material.dart';
import 'package:icue_ui/src/layout/icue_adaptive.dart';
import 'package:icue_ui/src/widgets/icue_toast_queue.dart';

/// Short messages shown above everything, including dialogs: top-right on wide
/// screens, full width at the top on phones.
///
/// ```dart
/// IcueToast.error(context, 'Could not save');
/// ```
abstract final class IcueToast {
  static final IcueToastQueue _queue = IcueToastQueue();
  static OverlayEntry? _entry;

  static void info(BuildContext context, String message) =>
      _show(context, IcueToastSeverity.info, message);

  static void success(BuildContext context, String message) =>
      _show(context, IcueToastSeverity.success, message);

  static void warning(BuildContext context, String message) =>
      _show(context, IcueToastSeverity.warning, message);

  static void error(BuildContext context, String message) =>
      _show(context, IcueToastSeverity.error, message);

  static void _show(
    BuildContext context,
    IcueToastSeverity severity,
    String message,
  ) {
    _queue.add(severity, message);
    if (_entry?.mounted ?? false) return;
    final entry = OverlayEntry(
      builder: (_) => _IcueToastLayer(queue: _queue, onEmpty: _remove),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  static void _remove() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry
      ..remove()
      ..dispose();
  }
}

class _IcueToastLayer extends StatelessWidget {
  const _IcueToastLayer({required this.queue, required this.onEmpty});

  final IcueToastQueue queue;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final isWide = context.isWide;
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final items = queue.items;
        if (items.isEmpty) {
          // Removing an entry while the overlay builds is not allowed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (queue.items.isEmpty) onEmpty();
          });
          return const SizedBox.shrink();
        }
        return SafeArea(
          child: Align(
            alignment: isWide ? Alignment.topRight : Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 400 : 600),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _IcueToastCard(
                            key: ValueKey(item.id),
                            item: item,
                            onClose: () => queue.dismiss(item.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IcueToastCard extends StatefulWidget {
  const _IcueToastCard({required this.item, required this.onClose, super.key});

  final IcueToastItem item;
  final VoidCallback onClose;

  @override
  State<_IcueToastCard> createState() => _IcueToastCardState();
}

class _IcueToastCardState extends State<_IcueToastCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(IcueToastQueue.visibleFor, widget.onClose);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  (Color, IconData) _style(ColorScheme scheme) =>
      switch (widget.item.severity) {
        IcueToastSeverity.info => (scheme.primary, Icons.info_outline_rounded),
        IcueToastSeverity.success => (
          Colors.green.shade700,
          Icons.check_circle_outline_rounded,
        ),
        IcueToastSeverity.warning => (
          Colors.orange.shade800,
          Icons.warning_amber_rounded,
        ),
        IcueToastSeverity.error => (scheme.error, Icons.error_outline_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (accent, icon) = _style(theme.colorScheme);
    return MouseRegion(
      onEnter: (_) => _timer?.cancel(),
      onExit: (_) => _startTimer(),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 6,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(color: accent, child: const SizedBox(width: 5)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: Icon(icon, color: accent),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Text(
                      widget.item.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
