import 'package:flutter/material.dart';
import 'package:gatepass/src/models/parent_gatepass_request.dart';
import 'package:gatepass/src/ui/widgets/gatepass_status_pill.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';

class GatePassRequestCard extends StatelessWidget {
  const GatePassRequestCard({
    required this.request,
    required this.typeName,
    super.key,
  });

  final ParentGatePassRequest request;
  final String typeName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date =
        request.statusDate.toDateOrNull()?.toDisplayDateTime() ??
        request.statusDate ??
        'N/A';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    typeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GatePassStatusPill(status: request.status),
              ],
            ),
            const Divider(height: 24),
            Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    ParentLocalizations.of(context).dateWithValue(date),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
