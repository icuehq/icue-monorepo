import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Branded background and centred, scrollable column shared by login and OTP.
class ParentAuthScaffold extends StatelessWidget {
  const ParentAuthScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(title: Text(title)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage(IcueAssets.authBackground),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
