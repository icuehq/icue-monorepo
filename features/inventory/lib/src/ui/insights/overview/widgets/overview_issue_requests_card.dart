import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:provider/provider.dart';

/// The newest pending issue requests, shown as a clean, scannable worklist on the dashboard.
class OverviewIssueRequestsCard extends StatefulWidget {
  const OverviewIssueRequestsCard({this.refreshVersion = 0, super.key});

  final int refreshVersion;

  @override
  State<OverviewIssueRequestsCard> createState() =>
      _OverviewIssueRequestsCardState();
}

class _OverviewIssueRequestsCardState extends State<OverviewIssueRequestsCard> {
  late Future<List<InventoryIssueRequest>> _requests;

  void _load() => _requests = context.read<StockProvider>().pendingRequests();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OverviewIssueRequestsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      setState(_load);
    }
  }

  Future<void> _open(InventoryIssueRequest request) async {
    await context.push(
      '${InventoryRoutes.inventoryRequestDetail}?id=${request.id}',
    );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.read<StockProvider>();
    final storeNames = {
      for (final store in context.watch<InventoryProvider>().stores)
        store.id: store.name,
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<List<InventoryIssueRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          final requests = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.11,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assignment_outlined,
                        size: 19,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Pending issue requests',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (requests != null && requests.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${requests.length}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Latest staff requests awaiting review or issue',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IcueButton(
                      label: 'View all',
                      onPressed: () =>
                          context.go(InventoryRoutes.inventoryRequests),
                      variant: IcueButtonVariant.ghost,
                      size: IcueButtonSize.small,
                      trailingIcon: Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          callableErrorMessage(snapshot.error!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                      IcueButton(
                        label: 'Retry',
                        onPressed: () => setState(_load),
                        variant: IcueButtonVariant.ghost,
                        size: IcueButtonSize.small,
                      ),
                    ],
                  ),
                )
              else if (requests == null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: IcueSkeletonPulse(
                    child: Column(
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          if (index > 0) const SizedBox(height: 12),
                          const IcueSkeletonBox(height: 54, radius: 10),
                        ],
                      ],
                    ),
                  ),
                )
              else if (requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.task_alt_rounded,
                          size: 20,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All caught up',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'No pending issue requests waiting for review right now.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (var index = 0; index < requests.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.30,
                      ),
                    ),
                  _IssueRequestRow(
                    request: requests[index],
                    storeName:
                        storeNames[requests[index].storeId] ??
                        requests[index].storeId,
                    itemName: stockProvider.itemName,
                    onTap: () => _open(requests[index]),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _IssueRequestRow extends StatelessWidget {
  const _IssueRequestRow({
    required this.request,
    required this.storeName,
    required this.itemName,
    required this.onTap,
  });

  final InventoryIssueRequest request;
  final String storeName;
  final String Function(String itemId) itemName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = inventoryStatusColor(request.status);
    final lineCount = request.lineItems.length;
    final firstLine = request.lineItems.firstOrNull;
    final primaryTitle = firstLine == null
        ? (request.purpose.isNotEmpty ? request.purpose : 'Issue request')
        : itemName(firstLine.itemId);
    final requester = request.requesterName?.isNotEmpty == true
        ? request.requesterName!
        : 'Staff #${request.createdBy}';
    final dateLabel = request.createdAt?.toIndianTime().toNumericDate();

    final summaryDetails = <String>[
      if (request.number.isNotEmpty) request.number,
      requester,
      storeName,
      ?dateLabel,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.035),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            primaryTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (lineCount > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${lineCount - 1} more',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summaryDetails,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (firstLine != null && lineCount == 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '× ${firstLine.requested.toQuantityText()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  humanizeStatus(request.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
