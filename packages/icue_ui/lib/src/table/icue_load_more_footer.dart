import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show FirestorePager;
import 'package:icue_ui/src/widgets/icue_button.dart';

/// The "Load more" row under a paged card list.
class IcueLoadMoreFooter extends StatelessWidget {
  const IcueLoadMoreFooter({required this.pager, super.key});

  final FirestorePager<Object?> pager;

  /// The footer for [pager], or null when there is no next page.
  static Widget? of(FirestorePager<Object?> pager) =>
      pager.hasNext ? IcueLoadMoreFooter(pager: pager) : null;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IcueButton(
        label: 'Load more',
        onPressed: pager.loading ? null : () => pager.next(append: true),
        variant: IcueButtonVariant.ghost,
      ),
    ),
  );
}
