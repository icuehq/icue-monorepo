import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

const _supportEmail = 'support@thoughtniques.com';

/// Shown when the entered number has no parent account.
Future<void> showNotRegisteredDialog(BuildContext context) {
  final l10n = ParentLocalizations.of(context);
  return IcueDialog.show<void>(
    context,
    title: l10n.thisPhoneNumberMayNotRegisteredWithUs,
    description: l10n.pleaseWriteToSupport,
    size: IcueDialogSize.small,
    secondaryAction: IcueDialogAction(
      label: l10n.close,
      variant: IcueButtonVariant.ghost,
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
    primaryAction: IcueDialogAction(
      label: l10n.sendEmail,
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop();
        launchUrl(Uri(scheme: 'mailto', path: _supportEmail));
      },
    ),
  );
}
