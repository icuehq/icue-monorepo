import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Today's menu. The texts are sample content, as in the old app.
class MealMenuPage extends StatelessWidget {
  const MealMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.mealMenu),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.todaysMenu,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _Section(
              title: l10n.breakfast,
              main: l10n.breadButterMasalaDosa,
              extra: l10n.beverages,
              image: 'packages/mess_meals/assets/lunch.png',
            ),
            _Section(
              title: l10n.lunch,
              main: l10n.mealDetail,
              icon: Icons.lunch_dining,
            ),
            _Section(
              title: l10n.snack,
              main: l10n.vegSaladCutlet,
              icon: Icons.fastfood_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.main,
    this.extra,
    this.icon,
    this.image,
  });

  final String title;
  final String main;
  final String? extra;
  final IconData? icon;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.primaryContainer;
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 10,
              children: [
                if (image != null)
                  Image.asset(image!, height: 30, color: dark)
                else
                  Icon(icon, size: 30, color: dark),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              main,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (extra != null && extra!.isNotEmpty)
              Text(
                extra!,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }
}
