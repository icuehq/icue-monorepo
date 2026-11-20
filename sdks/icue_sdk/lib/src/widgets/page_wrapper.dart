import 'package:flutter/material.dart';

import 'package:icue_sdk/src/widgets/no_data_widget.dart';

/// Styled container that provides loading and empty-state handling.
class PageWrapper extends StatelessWidget {
  const PageWrapper({
    super.key,
    required this.child,
    this.loading = false,
    this.hasData = true,
    this.msg,
  });

  final Widget child;
  final bool hasData;
  final bool loading;
  final String? msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        shape: const RoundedRectangleBorder(),
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : (!hasData || msg != null)
                ? NoDataWidget(msg: msg)
                : child,
      ),
    );
  }
}
