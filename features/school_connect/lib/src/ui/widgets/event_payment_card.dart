import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:school_connect/src/models/event_payment.dart';
import 'package:school_connect/src/models/event_timing.dart';
import 'package:school_connect/src/ui/widgets/event_payment_dialogs.dart';

class EventPaymentCard extends StatelessWidget {
  const EventPaymentCard({required this.payment, super.key});

  final EventPayment payment;

  static (Color, Color) _statusColors(String status) =>
      switch (status.toLowerCase()) {
        'completed' => (Colors.green.shade100, Colors.green.shade800),
        'failed' => (Colors.red.shade100, Colors.red.shade800),
        'initiated' => (Colors.orange.shade100, Colors.orange.shade800),
        _ => (Colors.grey.shade200, Colors.grey.shade800),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final (background, foreground) = _statusColors(payment.status);
    final paidAt = parsePaymentDateTime(
      payment.paymentDate,
      payment.paymentTime,
    );

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        collapsedShape: const RoundedRectangleBorder(),
        shape: const RoundedRectangleBorder(),
        leading: CircleAvatar(
          backgroundColor: primary.withValues(alpha: 0.1),
          foregroundColor: primary,
          child: const Icon(Icons.event_note),
        ),
        title: Text(
          payment.eventName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  payment.amount.toRupees(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IcueStatusPill(
                  label: payment.status,
                  color: foreground,
                  background: background,
                  bordered: false,
                  compact: true,
                ),
              ],
            ),
            Text(
              paidAt?.toDisplayDateTime() ??
                  '${payment.paymentDate} ${payment.paymentTime}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                _DetailRow(
                  icon: Icons.person,
                  label: l10n.students,
                  trailing: IcueButton(
                    label: l10n.view,
                    variant: IcueButtonVariant.outline,
                    size: IcueButtonSize.small,
                    onPressed: () =>
                        showStudentNames(context, payment.studentNames),
                  ),
                ),
                const SizedBox(height: 4),
                Text(l10n.paymentDetails, style: theme.textTheme.titleSmall),
                _DetailRow(
                  icon: Icons.currency_rupee_outlined,
                  label: l10n.subtotal,
                  value: payment.subAmount.toRupees(),
                ),
                _DetailRow(
                  icon: Icons.currency_rupee_outlined,
                  label: l10n.convenienceFee,
                  value: payment.convenienceFee.toRupees(),
                ),
                _DetailRow(
                  icon: Icons.currency_rupee_outlined,
                  label: l10n.total,
                  value: payment.amount.toRupees(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(l10n.bookingDetails, style: theme.textTheme.titleSmall),
                for (final (index, booking) in payment.bookings.indexed) ...[
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: l10n.attendDate,
                    value:
                        booking.attendDate.toDateOrNull()?.toDisplayDate() ??
                        booking.attendDate,
                  ),
                  _DetailRow(
                    icon: Icons.group_outlined,
                    label: l10n.attendees,
                    value: l10n.attendeesValue(
                      '${booking.booked}',
                      '${booking.attended}',
                    ),
                  ),
                  _DetailRow(
                    icon: Icons.price_change_outlined,
                    label: l10n.totalPrice,
                    value: booking.totalPrice.toRupees(),
                  ),
                  if (booking.answers.isNotEmpty)
                    _DetailRow(
                      icon: Icons.info_outline,
                      label: l10n.information,
                      trailing: IcueButton(
                        label: l10n.view,
                        variant: IcueButtonVariant.outline,
                        size: IcueButtonSize.small,
                        onPressed: () =>
                            showQuestionAnswers(context, booking.answers),
                      ),
                    ),
                  if (index != payment.bookings.length - 1)
                    const Divider(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Icon(icon, size: 16, color: Colors.grey.shade600),
      Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      ?trailing,
      if (value != null) Text(value!),
    ],
  );
}
