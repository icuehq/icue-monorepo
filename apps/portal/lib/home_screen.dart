import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:portal/widgets/home_module_card.dart';
import 'package:portal/widgets/home_welcome_banner.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

const _routeByState = <String, String>{
  'layout.stationeryinventory': InventoryRoutes.inventory,
  'layout.library': LibraryRoutes.library,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Provider notifies synchronously, which is illegal during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().getRoleActions();
    });
  }

  Future<void> _handleSignOut() async {
    final confirmed = await IcueDialog.confirm(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of the portal?',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (confirmed && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final actions = authProvider.roleActions;
    final user = authProvider.user;
    final scheme = Theme.of(context).colorScheme;

    final initials = user?.name.isNotEmpty == true
        ? user!.name
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'A';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.webp',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'iCue Portal',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'School Branch Management',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    user?.name ?? 'Admin',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(
              Icons.logout_rounded,
              size: 20,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: _handleSignOut,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: IcueCenteredBody(
        child: authProvider.isLoading && actions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading your school modules...',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : actions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: IcueEmptyState(
                    icon: Icons.school_outlined,
                    title: 'No Modules Available',
                    message: 'Your account does not have any active school branch modules assigned yet. Please contact your school administrator.',
                    actionLabel: 'Refresh Modules',
                    actionIcon: Icons.refresh_rounded,
                    onAction: () =>
                        context.read<AuthProvider>().getRoleActions(),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeWelcomeBanner(user: user),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text(
                          'Assigned Modules',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${actions.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isTwoColumn = constraints.maxWidth >= 640;
                        if (!isTwoColumn) {
                          return Column(
                            children: [
                              for (final action in actions) ...[
                                HomeModuleCard(
                                  action: action,
                                  onTap:
                                      _routeByState.containsKey(
                                        action.routeState,
                                      )
                                      ? () => context.go(
                                          _routeByState[action.routeState]!,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          );
                        }

                        final rows = <Widget>[];
                        for (var i = 0; i < actions.length; i += 2) {
                          final firstAction = actions[i];
                          final hasSecond = i + 1 < actions.length;
                          final secondAction = hasSecond
                              ? actions[i + 1]
                              : null;

                          rows.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: HomeModuleCard(
                                      action: firstAction,
                                      onTap:
                                          _routeByState.containsKey(
                                            firstAction.routeState,
                                          )
                                          ? () => context.go(
                                              _routeByState[firstAction
                                                  .routeState]!,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: secondAction != null
                                        ? HomeModuleCard(
                                            action: secondAction,
                                            onTap:
                                                _routeByState.containsKey(
                                                  secondAction.routeState,
                                                )
                                                ? () => context.go(
                                                    _routeByState[secondAction
                                                        .routeState]!,
                                                  )
                                                : null,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(children: rows);
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Need access to another module or branch? Contact your school administrator to update your permissions.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
