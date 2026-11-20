import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_sdk/src/pages/track_bus/live_tracking_page.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/services/injectable.dart';
import 'package:icue_sdk/src/services/notification_service.dart';
import 'package:provider/provider.dart';

/// Gatekeeper screen that validates authentication before showing Live Tracking.
class InitialPage extends StatefulWidget {
  const InitialPage({super.key});

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<UserProvider>().validateUserAuth();
      if (getIt.isRegistered<NotificationService>()) {
        await getIt<NotificationService>().syncTokenWithBackend();
      }
    });
  }

  Future<void> _validateAuth() async {
    if (!mounted) return;
    await context.read<UserProvider>().validateUserAuth();
    if (getIt.isRegistered<NotificationService>()) {
      await getIt<NotificationService>().syncTokenWithBackend();
    }
  }

  Widget _buildBody(String? error) {
    if (error != null) {
      return _ErrorView(message: error, onRetry: _validateAuth);
    }

    return const LiveTrackingPage();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final String? error = userProvider.errorMessage;

    return Scaffold(body: _buildBody(error));
  }
}

// ---

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  /// Human-readable description of what went wrong during validation.
  final String message;

  /// Callback to execute when the retry button is pressed.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    const double verticalSpacer = 16.0;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: verticalSpacer),
              ElevatedButton(
                onPressed: () {
                  onRetry();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
