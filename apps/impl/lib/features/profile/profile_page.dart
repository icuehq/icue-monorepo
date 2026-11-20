import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/di/injection.dart';
import 'package:impl/features/profile/profile_setting_tile.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/parent_transport.dart';
import 'package:provider/provider.dart';
import 'package:students/students.dart';

const _languageNames = {'en': 'English', 'es': 'Español'};

String _languageName(Locale locale) =>
    _languageNames[locale.languageCode] ?? locale.languageCode;

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.locale, super.key});

  final ValueNotifier<Locale> locale;

  Future<void> _pickLanguage(BuildContext context) async {
    final l10n = ParentLocalizations.of(context);
    var selected = Localizations.localeOf(context);
    final chosen = await IcueDialog.show<Locale>(
      context,
      title: l10n.selectLanguage,
      icon: Icons.language,
      size: IcueDialogSize.small,
      content: StatefulBuilder(
        builder: (context, setState) => RadioGroup<Locale>(
          groupValue: selected,
          onChanged: (value) => setState(() => selected = value!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in ParentLocalizations.supportedLocales)
                RadioListTile<Locale>(
                  value: item,
                  title: Text(_languageName(item)),
                  dense: true,
                ),
            ],
          ),
        ),
      ),
      secondaryAction: IcueDialogAction(
        label: l10n.cancel,
        variant: IcueButtonVariant.ghost,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      primaryAction: IcueDialogAction(
        label: 'OK',
        onPressed: () =>
            Navigator.of(context, rootNavigator: true).pop(selected),
      ),
    );
    if (chosen != null) locale.value = chosen;
  }

  Future<void> _logout(BuildContext context) async {
    final l10n = ParentLocalizations.of(context);
    final auth = context.read<ParentAuthProvider>();
    final confirmed = await IcueDialog.confirm(
      context,
      title: l10n.logout,
      message: l10n.areYouSureYouWantToLogout,
      confirmLabel: l10n.yes,
      destructive: true,
    );
    if (!confirmed) return;
    await auth.logout(deviceToken: await NotificationService.instance.token);
    if (context.mounted) context.read<ParentStudentsProvider>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final auth = context.watch<ParentAuthProvider>();
    final student = auth.selectedStudent;
    final version = getIt<ParentDeviceInfo>().appVersion;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.profile),
        bottom: IcueContextBar(label: student?.name),
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${l10n.appVersion} $version',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      ),
      body: IcueSheetBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileSettingTile(
              icon: Icons.child_care_outlined,
              title: l10n.children,
              onTap: () => context.go(StudentsRoutes.childrenPath),
            ),
            if (student?.enabledParentVehicles ?? false)
              ProfileSettingTile(
                icon: Icons.car_repair_outlined,
                title: l10n.myVehicles,
                onTap: () => context.go(TransportRoutes.myVehiclesPath),
              ),
            ProfileSettingTile(
              icon: Icons.language,
              title: l10n.language,
              subtitle: _languageName(Localizations.localeOf(context)),
              onTap: () => _pickLanguage(context),
            ),
            ProfileSettingTile(
              icon: Icons.description_outlined,
              title: l10n.termsAndConditions,
              onTap: () => context.go('/profile/terms-and-conditions'),
            ),
            ProfileSettingTile(
              icon: Icons.privacy_tip_outlined,
              title: l10n.privacyPolicy,
              onTap: () => context.go('/profile/privacy-policy'),
            ),
            const SizedBox(height: 10),
            IcueButton(
              label: l10n.logout,
              variant: IcueButtonVariant.destructive,
              leadingIcon: Icons.logout,
              isFullWidth: true,
              onPressed: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
