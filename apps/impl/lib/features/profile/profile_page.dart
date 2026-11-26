import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:impl/di/injection.dart';
import 'package:impl/features/profile/profile_setting_tile.dart';
import 'package:impl/features/profile/widgets/profile_header_card.dart';
import 'package:impl/features/profile/widgets/profile_section_card.dart';
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

  Widget _buildLogoutButton(BuildContext context, ParentLocalizations l10n) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.red.shade50.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _logout(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.logout,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final auth = context.watch<ParentAuthProvider>();
    final student = auth.selectedStudent;
    final version = getIt<ParentDeviceInfo>().appVersion;

    final parentName = student?.parentName?.trim();
    final displayName = (parentName != null && parentName.isNotEmpty)
        ? parentName
        : (student?.name ?? 'Parent');
    final childInfo = (parentName != null && parentName.isNotEmpty)
        ? (student?.name != null ? 'Student: ${student!.name}' : null)
        : (student?.schoolName ??
              (student?.classSection != null
                  ? 'Class ${student!.classSection}'
                  : null));
    final mobile = auth.mobile ?? student?.primaryContact;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(title: Text(l10n.profile)),
      body: IcueSheetBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            ProfileHeaderCard(
              displayName: displayName,
              mobile: mobile,
              childInfo: childInfo,
              childrenCount: auth.students.length,
            ),
            const SizedBox(height: 16),
            ProfileSectionCard(
              children: [
                ProfileSettingTile(
                  icon: Icons.child_care_rounded,
                  title: l10n.children,
                  trailing: auth.students.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${auth.students.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => context.go(StudentsRoutes.childrenPath),
                ),
                if (student?.enabledParentVehicles ?? false)
                  ProfileSettingTile(
                    icon: Icons.directions_car_outlined,
                    title: l10n.myVehicles,
                    onTap: () => context.go(TransportRoutes.myVehiclesPath),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ProfileSectionCard(
              children: [
                ProfileSettingTile(
                  icon: Icons.language_rounded,
                  title: l10n.language,
                  trailing: Text(
                    _languageName(Localizations.localeOf(context)),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
              ],
            ),
            const SizedBox(height: 20),
            _buildLogoutButton(context, l10n),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${l10n.appVersion} $version',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
