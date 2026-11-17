import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/routing/app_routes.dart';
import 'package:parent_l10n/parent_l10n.dart';

/// Shown for routes the app does not have.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.comingSoon)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/coming-soon.svg', height: 220),
              const SizedBox(height: 24),
              IcueButton(
                label: l10n.goToHomePage,
                onPressed: () => context.go(AppRoutes.dashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
