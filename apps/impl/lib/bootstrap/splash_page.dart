import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icue_ui/icue_ui.dart';

/// Shown while [AppBootstrap] runs startup tasks; swaps to a retry button if
/// they fail.
class SplashPage extends StatelessWidget {
  const SplashPage({this.error, this.onRetry, super.key});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: AssetImage(IcueAssets.authBackground),
              ),
            ),
          ),
          ColoredBox(color: scheme.surface.withValues(alpha: .85)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/splash.svg'),
                    const SizedBox(height: 28),
                    const Text(
                      "Stay connected to your child's school journey anytime, anywhere!",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (error == null)
                      const LinearProgressIndicator(minHeight: 4)
                    else ...[
                      const Text(
                        'Something went wrong while starting the app.',
                      ),
                      if (kDebugMode) SelectableText('$error'),
                      const SizedBox(height: 12),
                      IcueButton(label: 'Retry', onPressed: onRetry),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
