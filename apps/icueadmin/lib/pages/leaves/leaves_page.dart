import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/role_actions.dart';
import '../../services/hive_service.dart';

class LeavesPage extends StatelessWidget {
  const LeavesPage({super.key});

  static const String leaveBalanceRoute = 'layout.leavebalance';
  static const String leaveRequestRoute = 'layout.leaverequest';
  static const String leavesAppliedRoute = 'layout.leavesapplied';

  void _handleActionTap(BuildContext context, String routeState) {
    final route = routeState.startsWith('/')
        ? routeState
        : '/layout.leaves/$routeState';
    try {
      context.go(route);
    } catch (_) {
      // Catch in case GoRouter context is not provided (e.g. in widget test environments)
    }
  }

  Widget _buildCardForAction(BuildContext context, RoleActions action) {
    final state = action.routeState.toLowerCase();
    final name =
        (action.displayName.isNotEmpty ? action.displayName : action.name)
            .toLowerCase();

    if (state.contains('balance') || name.contains('balance')) {
      return _buildFeatureCard(
        context: context,
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: const Color(0xFFE0F2FE),
        title: action.displayName.isNotEmpty
            ? action.displayName
            : 'Leave Balance',
        subtitle:
            'View available leave balances, accrued quotas, and entitlement summary.',
        badge: 'Balances',
        badgeColor: const Color(0xFF0284C7),
        onTap: () => _handleActionTap(
          context,
          action.routeState.isNotEmpty ? action.routeState : leaveBalanceRoute,
        ),
      );
    } else if (state.contains('request') || name.contains('request')) {
      return _buildFeatureCard(
        context: context,
        icon: Icons.add_task_rounded,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        title: action.displayName.isNotEmpty
            ? action.displayName
            : 'Leave Request',
        subtitle:
            'Submit new leave applications with date selection, type, and reasons.',
        badge: 'Apply',
        badgeColor: const Color(0xFFD97706),
        onTap: () => _handleActionTap(
          context,
          action.routeState.isNotEmpty ? action.routeState : leaveRequestRoute,
        ),
      );
    } else if (state.contains('applied') || name.contains('applied')) {
      return _buildFeatureCard(
        context: context,
        icon: Icons.history_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
        title: action.displayName.isNotEmpty
            ? action.displayName
            : 'Leaves Applied',
        subtitle:
            'Track applied leave requests, monitor status, and view past history.',
        badge: 'History',
        badgeColor: const Color(0xFF2563EB),
        onTap: () => _handleActionTap(
          context,
          action.routeState.isNotEmpty ? action.routeState : leavesAppliedRoute,
        ),
      );
    }

    return _buildFeatureCard(
      context: context,
      icon: Icons.event_note_rounded,
      iconColor: const Color(0xFF0284C7),
      iconBgColor: const Color(0xFFE0F2FE),
      title: action.displayName.isNotEmpty ? action.displayName : action.name,
      subtitle: action.name,
      badge: 'Feature',
      badgeColor: const Color(0xFF64748B),
      onTap: () => _handleActionTap(context, action.routeState),
    );
  }

  List<Widget> _buildDefaultCards(BuildContext context) {
    return [
      _buildFeatureCard(
        context: context,
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: const Color(0xFFE0F2FE),
        title: 'Leave Balance',
        subtitle:
            'View available leave balances, accrued quotas, and entitlement summary.',
        badge: 'Balances',
        badgeColor: const Color(0xFF0284C7),
        onTap: () => _handleActionTap(context, leaveBalanceRoute),
      ),
      _buildFeatureCard(
        context: context,
        icon: Icons.add_task_rounded,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        title: 'Leave Request',
        subtitle:
            'Submit new leave applications with date selection, type, and reasons.',
        badge: 'Apply',
        badgeColor: const Color(0xFFD97706),
        onTap: () => _handleActionTap(context, leaveRequestRoute),
      ),
      _buildFeatureCard(
        context: context,
        icon: Icons.history_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
        title: 'Leaves Applied',
        subtitle:
            'Track applied leave requests, monitor status, and view past history.',
        badge: 'History',
        badgeColor: const Color(0xFF2563EB),
        onTap: () => _handleActionTap(context, leavesAppliedRoute),
      ),
    ];
  }

  Widget _buildContent(BuildContext context, List<Widget> cards) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
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
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBoxOpen = Hive.isBoxOpen('getActionsByRole-v2');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Leaves')),
      body: isBoxOpen
          ? ValueListenableBuilder(
              valueListenable: HiveService.getActionsByRoleBox.listenable(),
              builder: (context, box, _) {
                final leaveAction = box.values.firstWhereOrNull(
                  (e) => e.routeState == 'layout.leaves',
                );
                final subActions = leaveAction?.subActionItems ?? [];

                final List<Widget> cards;
                if (subActions.isNotEmpty) {
                  final sortedSubActions = List<RoleActions>.from(subActions)
                    ..sort((a, b) => a.tabOrder.compareTo(b.tabOrder));
                  cards = sortedSubActions
                      .map((action) => _buildCardForAction(context, action))
                      .toList();
                } else {
                  cards = _buildDefaultCards(context);
                }

                return _buildContent(context, cards);
              },
            )
          : _buildContent(context, _buildDefaultCards(context)),
    );
  }
}
