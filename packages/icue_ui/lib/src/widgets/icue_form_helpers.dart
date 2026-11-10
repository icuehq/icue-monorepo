import 'package:icue_ui/icue_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_firebase/icue_firebase.dart' show ErrorReporting;
import 'package:provider/provider.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [save]; closes the sheet or page on success, else shows the error of provider [P].
Future<bool> submitAndClose<P extends ErrorReporting>(
  BuildContext context,
  Future<bool> Function() save,
) async {
  final provider = context.read<P>();
  final navigator = Navigator.of(context);
  final saved = await save();
  if (!context.mounted) return saved;
  if (saved) {
    navigator.pop();
  } else {
    showMessage(context, provider.errorMessage ?? 'Could not save');
  }
  return saved;
}

/// [theme] with outlined and elevated buttons no longer forced to infinite width.
///
/// The app theme gives them `Size(double.infinity, 48)`, which breaks layout as soon as
/// one sits in a `Row` or `Wrap`; a dialog form may hold such rows.
ThemeData _finiteButtonWidths(ThemeData theme) {
  const minimumSize = WidgetStatePropertyAll(Size(64, 48));
  return theme.copyWith(
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: minimumSize,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (theme.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: minimumSize,
      ),
    ),
  );
}

/// Opens [form] as a dialog on wide screens, on its own full screen otherwise; it closes with `Navigator.pop`.
Future<void> showFormPage(BuildContext context, Widget Function() form) =>
    pushFormPage<void>(context, form);

/// Like [showFormPage], completing with the value the form pops with.
Future<T?> pushFormPage<T>(BuildContext context, Widget Function() form) {
  if (context.isWide) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: IcueBreakpoints.formMaxWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Theme(
                      data: _finiteButtonWidths(Theme.of(dialogContext)),
                      child: form(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: form(),
          ),
        ),
      ),
    ),
  );
}

String? requiredText(String? value) =>
    (value == null || value.trim().isEmpty) ? 'Required' : null;

String? optionalNumber(String? value) =>
    (value == null ||
        value.trim().isEmpty ||
        double.tryParse(value.trim()) != null)
    ? null
    : 'Enter a number';

/// Formatter allowing only non-negative decimal numbers with at most one dot.
final decimalInputFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final text = newValue.text;
  if (text.isEmpty) return newValue;
  return RegExp(r'^\d*\.?\d*$').hasMatch(text) ? newValue : oldValue;
});

String? blankToNull(TextEditingController controller) =>
    controller.text.trim().isEmpty ? null : controller.text.trim();

/// Comma-separated list → trimmed non-empty parts.
List<String> splitList(String value) => [
  for (final part in value.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

class IcueInactiveBadge extends StatelessWidget {
  const IcueInactiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Chip(
    label: const Text('Inactive'),
    visualDensity: VisualDensity.compact,
    backgroundColor: Colors.grey.shade200,
    labelStyle: const TextStyle(fontSize: 11),
  );
}

/// Empty-state action that creates a module's default master data (categories, units…).
class IcueSeedDefaultsButton<P extends ErrorReporting> extends StatelessWidget {
  const IcueSeedDefaultsButton({
    required this.label,
    required this.canSeed,
    required this.seed,
    super.key,
  });

  final String label;
  final bool Function(P provider) canSeed;
  final Future<bool> Function(P provider) seed;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<P>();
    if (!canSeed(provider)) return const SizedBox.shrink();
    return IcueButton(
      label: label,
      onPressed: () async {
        final seeded = await seed(provider);
        if (context.mounted && !seeded) {
          showMessage(context, provider.errorMessage ?? 'Failed');
        }
      },
      leadingIcon: Icons.auto_fix_high_rounded,
    );
  }
}
