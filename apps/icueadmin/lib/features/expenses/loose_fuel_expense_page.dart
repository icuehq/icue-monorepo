import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/expenses/widgets/expense_bill_section.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class LooseFuelArgs {
  const LooseFuelArgs({required this.expenseType, required this.storage});

  /// The `loosefuel` expense type.
  final ExpenseType expenseType;
  final StorageItem storage;
}

/// Fuel drawn from a campus storage (tank/drum) during a self-filling session.
class LooseFuelExpensePage extends StatefulWidget {
  const LooseFuelExpensePage({super.key, required this.args});

  final LooseFuelArgs args;

  @override
  State<LooseFuelExpensePage> createState() => _LooseFuelExpensePageState();
}

class _LooseFuelExpensePageState extends State<LooseFuelExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _litres = TextEditingController();
  final _vendor = TextEditingController();
  final _billNo = TextEditingController();
  final _description = TextEditingController();
  final _unusedAmount = TextEditingController();

  DateTime _billDate = DateTime.now();
  String _status = 'UnBilled';
  IcuePickedFile? _billFile;

  StorageItem get _storage => widget.args.storage;

  @override
  void initState() {
    super.initState();
    _price.text = _storage.fuelPrice ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _price,
      _litres,
      _vendor,
      _billNo,
      _description,
      _unusedAmount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final billed = _status != 'UnBilled';
    if (billed && _billFile == null) {
      _toast('Please upload Bill!');
      return;
    }

    final price = _price.text.trim();
    final litres = _litres.text.trim();
    final amount = (num.parse(litres) * num.parse(price)).toString();
    final provider = context.read<ExpenseProvider>();

    if (price != _storage.fuelPrice &&
        !await provider.updateFuelPrice(_storage.fuelType ?? '', price)) {
      if (mounted) _toast(provider.errorMessage ?? 'Failed to update price');
      return;
    }

    final success = await provider.submitExpense(
      StoreExpenseRequest(
        vehicleNumber: '',
        expenseType: widget.args.expenseType,
        billDate: _billDate.toUsDate(),
        billAmount: amount,
        billNo: billed ? _text(_billNo) : null,
        vendorName: _text(_vendor),
        status: _status,
        description: _text(_description),
        fuelType: _storage.fuelType,
        extraFields: {
          'StorType': _storage.type,
          'StorName': _storage.name,
          'StorCap': _storage.capacity,
          'FuelFilled': litres,
          'PricePerLitre': price,
        },
        billFileBytes: billed ? _billFile?.bytes : null,
        billFileName: billed ? _billFile?.name : null,
      ),
    );
    if (!mounted) return;
    if (success) {
      track(AppEvents.expenseSubmitted, {'type': 'loosefuel'});
      context.pushReplacement(
        AppRoutes.expenseConfirmation,
        extra: ExpenseConfirmationData(
          expenseType: widget.args.expenseType,
          vehicleNumber: _storage.name,
          amount: amount,
          mode: 'SelfFilling',
          fuelType: _storage.fuelType,
        ),
      );
    } else {
      _toast(provider.errorMessage ?? 'Failed to record expense.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final loading = context.watch<ExpenseProvider>().isLoading;
    String? positive(String? value) {
      final parsed = num.tryParse(value?.trim() ?? '');
      return parsed == null || parsed <= 0 ? 'Enter a valid number' : null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_storage.name)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${_storage.type} - ${_storage.fuelType}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType: decimal,
              decoration: const InputDecoration(
                labelText: 'Current Fuel Price *',
                border: OutlineInputBorder(),
              ),
              validator: positive,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _litres,
              keyboardType: decimal,
              decoration: const InputDecoration(
                labelText: 'Fuel Filled *',
                border: OutlineInputBorder(),
              ),
              validator: positive,
            ),
            const SizedBox(height: 16),
            ExpenseBillSection(
              billDate: _billDate,
              onSelectBillDate: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _billDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _billDate = picked);
              },
              billNoController: _billNo,
              billAmountController: _unusedAmount,
              vendorNameController: _vendor,
              showAmount: false,
              status: _status,
              onStatusChanged: (val) =>
                  setState(() => _status = val ?? 'UnBilled'),
              billFileName: _billFile?.name,
              onPickBillFile: () async {
                final picked = await pickFile(context);
                if (picked != null && mounted) {
                  setState(() => _billFile = picked);
                }
              },
              onRemoveBillFile: () => setState(() => _billFile = null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            IcueButton(
              label: 'Submit',
              onPressed: loading ? null : _submit,
              isLoading: loading,
            ),
          ],
        ),
      ),
    );
  }
}
