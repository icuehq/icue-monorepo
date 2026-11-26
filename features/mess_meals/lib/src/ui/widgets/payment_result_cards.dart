import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';

Widget _card(BuildContext context, List<Widget> children) => Card(
  elevation: 3,
  margin: const EdgeInsets.symmetric(horizontal: 20),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: children,
    ),
  ),
);

class PaymentLoadingCard extends StatelessWidget {
  const PaymentLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    return _card(context, [
      const SizedBox(
        height: 64,
        width: 64,
        child: CircularProgressIndicator(strokeWidth: 4),
      ),
      Text(
        l10n.redirectingToGateway,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      Text(
        l10n.dontCloseApp,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ]);
  }
}

class PaymentSuccessCard extends StatelessWidget {
  const PaymentSuccessCard({
    required this.orderId,
    required this.onClose,
    super.key,
  });

  final String orderId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    return _card(context, [
      CircleAvatar(
        radius: 40,
        backgroundColor: theme.colorScheme.primary,
        child: Icon(
          Icons.check_rounded,
          size: 56,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      Text(
        l10n.paymentSuccessful,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(l10n.orderPlaced, textAlign: TextAlign.center),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Chip(label: Text(l10n.orderIdLabel(orderId))),
          IconButton(
            tooltip: l10n.copyOrderId,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: orderId));
              if (context.mounted) {
                IcueToast.info(context, l10n.orderIdCopied);
              }
            },
          ),
        ],
      ),
      IcueButton(label: l10n.done, isFullWidth: true, onPressed: onClose),
    ]);
  }
}

class PaymentFailureCard extends StatelessWidget {
  const PaymentFailureCard({
    required this.message,
    required this.onRetry,
    required this.onClose,
    super.key,
  });

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    return _card(context, [
      CircleAvatar(
        radius: 40,
        backgroundColor: theme.colorScheme.error,
        child: Icon(
          Icons.error_outline_rounded,
          size: 56,
          color: theme.colorScheme.onError,
        ),
      ),
      Text(
        l10n.paymentFailed,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      if (message != null) Text(message!, textAlign: TextAlign.center),
      Row(
        spacing: 12,
        children: [
          Expanded(
            child: IcueButton(
              label: l10n.goBack,
              variant: IcueButtonVariant.outline,
              onPressed: onClose,
            ),
          ),
          Expanded(
            child: IcueButton(label: l10n.retry, onPressed: onRetry),
          ),
        ],
      ),
    ]);
  }
}
