import 'package:flutter/material.dart';

/// Shown while [AppBootstrap] runs startup tasks; swaps to a retry button if
/// they fail.
class SplashPage extends StatelessWidget {
  const SplashPage({this.error, this.onRetry, super.key});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 160),
            const SizedBox(height: 32),
            if (error == null)
              const CircularProgressIndicator()
            else ...[
              Text(
                'Something went wrong while starting the app.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
