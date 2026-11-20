import 'package:flutter/material.dart';
import 'package:icue_ui/src/widgets/icue_empty_state.dart';

/// White body with rounded top corners that sits under a coloured app bar
/// (set the Scaffold background to the primary colour). Shows a spinner while
/// [loading] and an empty state when [hasData] is false.
class IcueSheetBody extends StatelessWidget {
  const IcueSheetBody({
    required this.child,
    this.loading = false,
    this.hasData = true,
    this.emptyTitle = 'No data found',
    super.key,
  });

  final Widget child;
  final bool loading;
  final bool hasData;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        color: Colors.white,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : hasData
            ? child
            : IcueEmptyState(
                icon: Icons.inbox_outlined,
                title: emptyTitle,
                neutral: true,
              ),
      ),
    );
  }
}
