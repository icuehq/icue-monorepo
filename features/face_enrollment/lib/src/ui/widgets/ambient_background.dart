import 'package:flutter/material.dart';

/// Plain themed page background.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);
}
