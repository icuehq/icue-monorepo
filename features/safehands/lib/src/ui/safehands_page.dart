import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:safehands/src/providers/safehands_provider.dart';
import 'package:safehands/src/ui/routing/safehands_router.dart';

const _artwork = 'packages/safehands/assets/safe-hands.svg';

/// Shows today's pickup PIN, or a button to generate one.
class SafeHandsPage extends StatefulWidget {
  const SafeHandsPage({super.key});

  @override
  State<SafeHandsPage> createState() => _SafeHandsPageState();
}

class _SafeHandsPageState extends State<SafeHandsPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<SafeHandsProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<SafeHandsProvider>();
    final auth = context.watch<ParentAuthProvider>();
    final pin = provider.pin;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.safeHands),
        bottom: IcueContextBar(label: auth.selectedStudent?.name),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: auth.selectedStudent?.isEscortPhotos == false
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(SafeHandsRoutes.escortPath),
              label: Text(
                l10n.escort,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: IcueSheetBody(
        loading: provider.loading,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: pin == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20,
                  children: [
                    SvgPicture.asset(_artwork, height: 200),
                    IcueButton(
                      label: l10n.generatePin,
                      isFullWidth: true,
                      size: IcueButtonSize.large,
                      onPressed: provider.generate,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 20,
                      children: [
                        SvgPicture.asset(_artwork, height: 80),
                        Text(
                          l10n.safeHandsPin,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(pin.heading, style: const TextStyle(fontSize: 18)),
                    const Divider(height: 32),
                    Center(
                      child: Text(
                        '${pin.pin}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
