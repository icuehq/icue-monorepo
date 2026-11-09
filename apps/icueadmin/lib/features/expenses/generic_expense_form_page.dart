import 'package:core_ui/core_ui.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/expenses/widgets/expense_bill_section.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class GenericExpenseArgs {
  const GenericExpenseArgs({
    required this.expenseType,
    required this.vehicleNumber,
    this.fuelType,
    this.fuelPrice,
    this.mode,
  });

  final ExpenseType expenseType;
  final String vehicleNumber;
  final String? fuelType;
  final String? fuelPrice;
  final String? mode;
}

/// One form for battery, tyres, maintenance, salary and fuel-station
/// expenses. The submitted keys are the legacy backend contract.
class GenericExpenseFormPage extends StatefulWidget {
  const GenericExpenseFormPage({super.key, required this.args});

  final GenericExpenseArgs args;

  @override
  State<GenericExpenseFormPage> createState() => _GenericExpenseFormPageState();
}

class _GenericExpenseFormPageState extends State<GenericExpenseFormPage> {
  static const _otherSubCategory = 'others';

  final _formKey = GlobalKey<FormState>();
  final _billNo = TextEditingController();
  final _billAmount = TextEditingController();
  final _vendorName = TextEditingController();
  final _odometer = TextEditingController();
  final _description = TextEditingController();
  final _warranty = TextEditingController();
  final _batteryName = TextEditingController();
  final _batteryCapacity = TextEditingController();
  final _batteryNumber = TextEditingController();
  final _tyreName = TextEditingController();
  final _tyreNumber = TextEditingController();
  final _otherSubCategoryName = TextEditingController();
  final _fuelLitres = TextEditingController();
  final _fuelPrice = TextEditingController();
  final _name = TextEditingController();

  DateTime _billDate = DateTime.now();
  DateTime _fixedDate = DateTime.now();
  String _status = 'UnBilled';
  String? _tyreType;
  String? _salaryMode;
  Detail? _category;
  Detail? _subCategory;
  PickedFile? _billFile;
  PickedFile? _odometerFile;

  String get _code => widget.args.expenseType.code;
  bool get _isFuel => _code == 'fuel';
  bool get _hasFixedDate =>
      _code == 'battery' || _code == 'tyres' || _code == 'maintenance';

  @override
  void initState() {
    super.initState();
    _fuelPrice.text = widget.args.fuelPrice ?? '';
    if (_code == 'maintenance') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ExpenseProvider>().fetchExpenseCategories();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _billNo,
      _billAmount,
      _vendorName,
      _odometer,
      _description,
      _warranty,
      _batteryName,
      _batteryCapacity,
      _batteryNumber,
      _tyreName,
      _tyreNumber,
      _otherSubCategoryName,
      _fuelLitres,
      _fuelPrice,
      _name,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(
    DateTime current,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Map<String, dynamic> _typeFields() {
    switch (_code) {
      case 'battery':
        return {
          'BatteryName': _text(_batteryName),
          'BatteryCapacity': _text(_batteryCapacity),
          'BatteryNo': _text(_batteryNumber),
          'Warranty': _text(_warranty),
        };
      case 'tyres':
        return {
          'Type': _tyreType,
          'TyreName': _text(_tyreName),
          'TyreNo': _text(_tyreNumber),
          'Warranty': _text(_warranty),
        };
      case 'maintenance':
        final other = _subCategory?.id.toString() == _otherSubCategory;
        return {
          'CategoryId': _category?.id,
          'CategoryName': _category?.name,
          'SubCategoryId': _subCategory?.id,
          'SubCategoryName': other
              ? _text(_otherSubCategoryName)
              : _subCategory?.name,
        };
      case 'salary':
        return {'Name': _text(_name)};
      case 'fuel':
        return {'KM': _text(_odometer), 'FuelFilled': _text(_fuelLitres)};
    }
    return {};
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isFuel && _odometerFile == null) {
      _toast('Please upload Odometer readings!');
      return;
    }
    if (_status != 'UnBilled' && _billFile == null) {
      _toast('Please upload Bill!');
      return;
    }

    final provider = context.read<ExpenseProvider>();
    if (_isFuel &&
        _fuelPrice.text.trim() != widget.args.fuelPrice &&
        !await provider.updateFuelPrice(
          widget.args.fuelType ?? '',
          _fuelPrice.text.trim(),
        )) {
      if (mounted) _toast(provider.errorMessage ?? 'Failed to update price');
      return;
    }

    final billed = _status != 'UnBilled';
    final request = StoreExpenseRequest(
      vehicleNumber: widget.args.vehicleNumber,
      expenseType: widget.args.expenseType,
      billDate: _billDate.toUsDate(),
      billAmount: _isFuel ? '' : _billAmount.text.trim(),
      billNo: billed ? _text(_billNo) : null,
      vendorName: _text(_vendorName),
      status: _status,
      description: _text(_description),
      mode: _isFuel
          ? widget.args.mode
          : (_code == 'salary' ? _salaryMode : null),
      fuelType: _isFuel ? widget.args.fuelType : null,
      speedometer: _isFuel ? null : _text(_odometer),
      extraFields: {
        ..._typeFields(),
        if (_hasFixedDate) 'FixedDate': _fixedDate.toUsDate(),
      },
      billFileBytes: billed ? _billFile?.bytes : null,
      billFileName: billed ? _billFile?.name : null,
      odometerFileBytes: _odometerFile?.bytes,
      odometerFileName: _odometerFile?.name,
    );

    final success = await provider.submitExpense(request);
    if (!mounted) return;
    if (success) {
      track(AppEvents.expenseSubmitted, {'type': '${widget.args.expenseType}'});
      context.pushReplacement(
        AppRoutes.expenseConfirmation,
        extra: ExpenseConfirmationData(
          expenseType: widget.args.expenseType,
          vehicleNumber: widget.args.vehicleNumber,
          amount: _isFuel ? null : _billAmount.text.trim(),
          mode: widget.args.mode,
          fuelType: widget.args.fuelType,
        ),
      );
    } else {
      _toast(
        provider.errorMessage ?? 'Failed to record expense. Please try again.',
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (val) => val == null || val.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '$label *',
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in items)
            DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
        ],
        onChanged: onChanged,
        validator: (val) => val == null ? 'Required' : null,
      ),
    );
  }

  Widget _fixedDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pickDate(_fixedDate, (d) => _fixedDate = d),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fixed Date *',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
          ),
          child: Text(_fixedDate.toNumericDate()),
        ),
      ),
    );
  }

  Widget _odometerImage() {
    final name = _odometerFile?.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppButton(
        label: name ?? 'Upload Odometer *',
        onPressed: () async {
          final picked = await pickFile(context);
          if (picked != null && mounted) setState(() => _odometerFile = picked);
        },
        variant: AppButtonVariant.outline,
        leadingIcon: Icons.camera_alt,
      ),
    );
  }

  List<Widget> _typeSpecificFields(ExpenseProvider provider) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    switch (_code) {
      case 'battery':
        return [
          _field(_batteryName, 'Battery Name'),
          _field(_batteryCapacity, 'Battery Capacity'),
          _field(_batteryNumber, 'Battery Number'),
          _field(_odometer, 'Odometer', keyboardType: TextInputType.number),
          _field(
            _warranty,
            'Warranty (In Months)',
            keyboardType: TextInputType.number,
          ),
          _fixedDateField(),
        ];
      case 'tyres':
        final types = widget.args.expenseType.expenseTypeDetails
            .where((e) => e.code == 'Type')
            .expand((e) => e.details)
            .map((e) => e.name)
            .toList();
        return [
          _dropdown<String>(
            label: 'Type',
            value: _tyreType,
            items: types,
            itemLabel: (e) => e,
            onChanged: (val) => setState(() => _tyreType = val),
          ),
          _field(_tyreName, 'Tyre Name (Brand)'),
          _field(_tyreNumber, 'Tyre Number/Size'),
          _field(_odometer, 'Odometer', keyboardType: TextInputType.number),
          _field(
            _warranty,
            'Warranty (In Months)',
            keyboardType: TextInputType.number,
          ),
          _fixedDateField(),
        ];
      case 'maintenance':
        final subCategories = [
          ...provider.subCategories,
          const Detail(id: _otherSubCategory, name: 'Others'),
        ];
        return [
          _dropdown<Detail>(
            label: 'Category',
            value: _category,
            items: provider.categories,
            itemLabel: (e) => e.name,
            onChanged: (val) {
              setState(() {
                _category = val;
                _subCategory = null;
              });
              if (val != null) {
                provider.fetchExpenseSubCategories(
                  int.tryParse(val.id.toString()) ?? 0,
                );
              }
            },
          ),
          if (_category != null)
            _dropdown<Detail>(
              label: 'Sub Category',
              value: _subCategory,
              items: subCategories,
              itemLabel: (e) => e.name,
              onChanged: (val) => setState(() => _subCategory = val),
            ),
          if (_subCategory?.id.toString() == _otherSubCategory)
            _field(_otherSubCategoryName, 'Other Sub Category'),
          _field(_odometer, 'Odometer', keyboardType: TextInputType.number),
          _fixedDateField(),
        ];
      case 'salary':
        return [
          _dropdown<String>(
            label: 'Mode',
            value: _salaryMode,
            items: widget.args.expenseType.modes.map((e) => e.code).toList(),
            itemLabel: (code) => widget.args.expenseType.modes
                .firstWhere((e) => e.code == code)
                .name,
            onChanged: (val) => setState(() => _salaryMode = val),
          ),
          _field(_name, 'Name'),
        ];
      case 'fuel':
        return [
          _field(_fuelPrice, 'Current Fuel Price', keyboardType: decimal),
          _field(
            _odometer,
            'Current KMS Reading',
            keyboardType: TextInputType.number,
          ),
          _field(_fuelLitres, 'Fuel Filled', keyboardType: decimal),
          _odometerImage(),
        ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.args.expenseType.expenseTypeDesc} - ${widget.args.vehicleNumber}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._typeSpecificFields(provider),
            const Divider(),
            const SizedBox(height: 12),
            ExpenseBillSection(
              billDate: _billDate,
              onSelectBillDate: () =>
                  _pickDate(_billDate, (d) => _billDate = d),
              billNoController: _billNo,
              billAmountController: _billAmount,
              vendorNameController: _vendorName,
              showAmount: !_isFuel,
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
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Submit Expense Record',
              onPressed: provider.isLoading ? null : _submit,
              leadingIcon: Icons.check_circle_outline,
              isLoading: provider.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
