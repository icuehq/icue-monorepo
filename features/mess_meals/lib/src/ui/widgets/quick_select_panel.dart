import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parent_l10n/parent_l10n.dart';

/// Buttons and a number field that pick the first N available days.
class QuickSelectPanel extends StatefulWidget {
  const QuickSelectPanel({
    required this.available,
    required this.onCount,
    super.key,
  });

  /// Days the parent can pick in total.
  final int available;

  /// Called with how many of the earliest available days to select.
  final ValueChanged<int> onCount;

  @override
  State<QuickSelectPanel> createState() => _QuickSelectPanelState();
}

class _QuickSelectPanelState extends State<QuickSelectPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _invalid => (int.tryParse(_controller.text) ?? 0) > widget.available;

  void _pick(int count) {
    _controller.clear();
    widget.onCount(count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = _invalid ? scheme.error : scheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: scheme.primary),
              Expanded(
                child: Text(
                  l10n.quickSelectDays(widget.available),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _pick(5),
                child: Text(l10n.daysCount(5)),
              ),
              OutlinedButton(
                onPressed: () => _pick(10),
                child: Text(l10n.daysCount(10)),
              ),
              OutlinedButton(
                onPressed: () => _pick(widget.available),
                child: Text(l10n.allAvailable),
              ),
              SizedBox(
                width: 90,
                height: 36,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.custom,
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {});
                    widget.onCount(int.tryParse(text) ?? 0);
                  },
                ),
              ),
            ],
          ),
          if (_invalid)
            Text(
              l10n.onlyWorkingDays(widget.available),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
