import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gatepass/src/providers/parent_gatepass_provider.dart';
import 'package:gatepass/src/ui/routing/gatepass_router.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// Parent requests a gate pass for today.
class GenerateGatePassPage extends StatefulWidget {
  const GenerateGatePassPage({super.key});

  @override
  State<GenerateGatePassPage> createState() => _GenerateGatePassPageState();
}

class _GenerateGatePassPageState extends State<GenerateGatePassPage> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<ParentGatePassProvider>().loadTypes(),
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final result = await context.read<ParentGatePassProvider>().requestPass(
      _category!,
    );
    if (!mounted) return;
    if (result.ok) {
      setState(() => _requested = true);
    } else if (result.message != null) {
      IcueToast.error(context, result.message!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<ParentGatePassProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.generateGatePass),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(GatePassRoutes.requestsPath),
        icon: const Icon(Icons.list),
        label: Text(l10n.viewRequests),
      ),
      body: IcueSheetBody(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _requested
                ? _Success(onHome: () => context.pop())
                : ListView(
                    children: [
                      _TodayNotice(
                        text: l10n.gatePassDateInfo(
                          DateTime.now().toIndianTime().toDisplayDate(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      IcueDropdown<String>(
                        label: l10n.gatePassType,
                        value: _category,
                        items: [
                          for (final type in provider.types)
                            DropdownMenuItem(
                              value: type.category,
                              child: Text(type.displayName),
                            ),
                        ],
                        validator: (value) =>
                            value == null ? l10n.thisIsRequired : null,
                        onChanged: (value) => setState(() => _category = value),
                      ),
                      const SizedBox(height: 26),
                      IcueButton(
                        label: l10n.requestGatePass,
                        isFullWidth: true,
                        isLoading: provider.requesting,
                        onPressed: provider.requesting ? null : _submit,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TodayNotice extends StatelessWidget {
  const _TodayNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Success extends StatelessWidget {
  const _Success({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 16,
      children: [
        const Icon(Icons.verified, color: Color(0xFF12967E), size: 90),
        Text(
          l10n.gatePassRequestedSuccessfully,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            color: Color(0xFF12967E),
            fontWeight: FontWeight.w600,
          ),
        ),
        IcueButton(
          label: l10n.home,
          variant: IcueButtonVariant.outline,
          onPressed: onHome,
        ),
      ],
    );
  }
}
