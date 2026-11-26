import 'dart:async';

import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Logout'),
      content: const SizedBox(
        width: 500,
        child: Text('Are you sure you want to logout?'),
      ),
      actions: [
        IcueButton(
          label: 'No',
          onPressed: () {
            unawaited(HapticFeedback.vibrate());
            Navigator.of(context).pop();
          },
          variant: IcueButtonVariant.ghost,
        ),
        IcueButton(
          label: 'Yes',
          onPressed: () async {
            unawaited(HapticFeedback.vibrate());
            final auth = context.read<AuthProvider>();
            final navigator = Navigator.of(context)..pop();
            unawaited(
              showDialog<void>(
                context: navigator.context,
                barrierDismissible: false,
                builder: (_) => const PopScope(
                  canPop: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            );
            try {
              await auth.logout();
            } finally {
              if (navigator.mounted) navigator.pop();
            }
          },
        ),
      ],
    );
  }
}
