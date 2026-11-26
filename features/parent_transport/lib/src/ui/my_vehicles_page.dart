import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/src/providers/parent_vehicles_provider.dart';
import 'package:provider/provider.dart';

final _plate = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$');

/// Profile > My Vehicles: the parent's own vehicles allowed to enter the school.
class MyVehiclesPage extends StatefulWidget {
  const MyVehiclesPage({super.key});

  @override
  State<MyVehiclesPage> createState() => _MyVehiclesPageState();
}

class _MyVehiclesPageState extends State<MyVehiclesPage> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<ParentVehiclesProvider>().load(),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final l10n = ParentLocalizations.of(context);
    final saved = await context.read<ParentVehiclesProvider>().add(
      _number.text.trim(),
    );
    if (!mounted || !saved) return;
    _number.clear();
    IcueToast.success(context, l10n.vehicleAdded);
  }

  Future<void> _delete(int id, String plate) async {
    final l10n = ParentLocalizations.of(context);
    final provider = context.read<ParentVehiclesProvider>();
    final confirmed = await IcueDialog.confirm(
      context,
      title: l10n.deleteVehicleTitle,
      message: l10n.deleteVehicleMessage(plate),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    final removed = await provider.remove(id);
    if (mounted && removed) IcueToast.success(context, l10n.vehicleDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<ParentVehiclesProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      appBar: AppBar(
        title: Text(l10n.myVehicles),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        child: RefreshIndicator(
          onRefresh: provider.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        Text(
                          l10n.addAVehicle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        IcueTextField(
                          controller: _number,
                          label: l10n.vehicleNumber,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [_UpperCaseFormatter()],
                          validator: (value) {
                            final text = value?.trim().toUpperCase() ?? '';
                            if (text.isEmpty) return l10n.vehicleRequired;
                            return _plate.hasMatch(text)
                                ? null
                                : l10n.vehicleInvalid;
                          },
                          onFieldSubmitted: (_) => _add(),
                        ),
                        IcueButton(
                          label: l10n.addVehicle,
                          leadingIcon: Icons.add_rounded,
                          isFullWidth: true,
                          isLoading: provider.loading,
                          onPressed: provider.loading ? null : _add,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.savedVehicles,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (provider.vehicles.isEmpty && !provider.loading)
                IcueEmptyState(
                  icon: Icons.directions_car_outlined,
                  title: l10n.noVehiclesYet,
                  message: l10n.addFirstVehicle,
                  neutral: true,
                ),
              for (final vehicle in provider.vehicles)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: scheme.primary),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.directions_car_rounded,
                      color: scheme.primary,
                    ),
                    title: Text(
                      vehicle.vehicleNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: l10n.delete,
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      onPressed: () =>
                          _delete(vehicle.id, vehicle.vehicleNumber),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase().trim());
}
