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
    this.mode,
  });

  final ExpenseType expenseType;
  final String vehicleNumber;
  final String? fuelType;
  final String? mode;
}

class GenericExpenseFormPage extends StatefulWidget {
  const GenericExpenseFormPage({super.key, required this.args});

  final GenericExpenseArgs args;

  @override
  State<GenericExpenseFormPage> createState() => _GenericExpenseFormPageState();
}

class _GenericExpenseFormPageState extends State<GenericExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _billDate = DateTime.now();
  String _status = 'UnBilled';
  final TextEditingController _billNoController = TextEditingController();
  final TextEditingController _billAmountController = TextEditingController();
  final TextEditingController _vendorNameController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Battery specific
  final TextEditingController _batteryNameController = TextEditingController();
  final TextEditingController _batteryCapacityController =
      TextEditingController();
  final TextEditingController _batteryNoController = TextEditingController();
  final TextEditingController _warrantyController = TextEditingController();

  // Tyres specific
  final TextEditingController _tyreBrandController = TextEditingController();
  final TextEditingController _tyreSizeController = TextEditingController();
  final TextEditingController _tyreQtyController = TextEditingController();

  // Maintenance specific
  int? _selectedCategoryId;
  String? _selectedSubCategory;

  // Fuel specific
  final TextEditingController _fuelQtyController = TextEditingController();
  final TextEditingController _fuelRateController = TextEditingController();

  // Salary specific
  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _salaryMonthController = TextEditingController();

  String? _billFileName;
  List<int>? _billFileBytes;

  @override
  void initState() {
    super.initState();
    if (widget.args.expenseType.code == 'maintenance') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ExpenseProvider>().fetchExpenseCategories();
      });
    }
  }

  @override
  void dispose() {
    _billNoController.dispose();
    _billAmountController.dispose();
    _vendorNameController.dispose();
    _odometerController.dispose();
    _descController.dispose();
    _batteryNameController.dispose();
    _batteryCapacityController.dispose();
    _batteryNoController.dispose();
    _warrantyController.dispose();
    _tyreBrandController.dispose();
    _tyreSizeController.dispose();
    _tyreQtyController.dispose();
    _fuelQtyController.dispose();
    _fuelRateController.dispose();
    _staffNameController.dispose();
    _salaryMonthController.dispose();
    super.dispose();
  }

  Future<void> _selectBillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _billDate = picked);
    }
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubCategory = null;
    });
    if (categoryId != null) {
      context.read<ExpenseProvider>().fetchExpenseSubCategories(categoryId);
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final dateFormatted = AppDateUtils.formatDate(_billDate);

    final extraFields = <String, dynamic>{};
    final code = widget.args.expenseType.code;

    if (code == 'battery') {
      extraFields['BatteryName'] = _batteryNameController.text.trim();
      extraFields['BatteryCapacity'] = _batteryCapacityController.text.trim();
      extraFields['BatteryNo'] = _batteryNoController.text.trim();
      extraFields['Warranty'] = _warrantyController.text.trim();
    } else if (code == 'tyres') {
      extraFields['TyreBrand'] = _tyreBrandController.text.trim();
      extraFields['TyreSize'] = _tyreSizeController.text.trim();
      extraFields['Quantity'] = _tyreQtyController.text.trim();
    } else if (code == 'maintenance') {
      extraFields['CategoryId'] = _selectedCategoryId;
      extraFields['SubCategory'] = _selectedSubCategory;
    } else if (code == 'fuel') {
      extraFields['Litres'] = _fuelQtyController.text.trim();
      extraFields['Rate'] = _fuelRateController.text.trim();
      extraFields['FuelType'] = widget.args.fuelType;
    } else if (code == 'salary') {
      extraFields['StaffName'] = _staffNameController.text.trim();
      extraFields['SalaryMonth'] = _salaryMonthController.text.trim();
    }

    final req = StoreExpenseRequest(
      vehicleNumber: widget.args.vehicleNumber,
      expenseType: widget.args.expenseType,
      billDate: dateFormatted,
      billAmount: _billAmountController.text.trim(),
      billNo: _billNoController.text.trim().isNotEmpty
          ? _billNoController.text.trim()
          : null,
      vendorName: _vendorNameController.text.trim().isNotEmpty
          ? _vendorNameController.text.trim()
          : null,
      status: _status,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      speedometer: _odometerController.text.trim().isNotEmpty
          ? _odometerController.text.trim()
          : null,
      mode: widget.args.mode,
      fuelType: widget.args.fuelType,
      extraFields: extraFields,
      billFileBytes: _billFileBytes,
      billFileName: _billFileName,
    );

    final success = await context.read<ExpenseProvider>().submitExpense(req);

    if (!mounted) return;

    if (success) {
      track(AppEvents.expenseSubmitted, {'type': '${widget.args.expenseType}'});
      context.pushReplacement(
        AppRoutes.expenseConfirmation,
        extra: ExpenseConfirmationData(
          expenseType: widget.args.expenseType,
          vehicleNumber: widget.args.vehicleNumber,
          amount: _billAmountController.text.trim(),
          mode: widget.args.mode,
          fuelType: widget.args.fuelType,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ExpenseProvider>().errorMessage ??
                'Failed to record expense. Please try again.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final code = widget.args.expenseType.code;

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
            ExpenseBillSection(
              billDate: _billDate,
              onSelectBillDate: _selectBillDate,
              billNoController: _billNoController,
              billAmountController: _billAmountController,
              vendorNameController: _vendorNameController,
              status: _status,
              onStatusChanged: (val) =>
                  setState(() => _status = val ?? 'UnBilled'),
              billFileName: _billFileName,
              onPickBillFile: () {
                setState(() {
                  _billFileName = 'invoice_sample.jpg';
                  _billFileBytes = [0, 1, 2, 3];
                });
              },
              onRemoveBillFile: () {
                setState(() {
                  _billFileName = null;
                  _billFileBytes = null;
                });
              },
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '${widget.args.expenseType.expenseTypeDesc} Details',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (code != 'salary') ...[
              TextFormField(
                controller: _odometerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Odometer / Speedometer (KM) *',
                  border: OutlineInputBorder(),
                  suffixText: 'km',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
            ],
            if (code == 'battery') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batteryNameController,
                      decoration: const InputDecoration(
                        labelText: 'Battery Brand *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _batteryCapacityController,
                      decoration: const InputDecoration(
                        labelText: 'Capacity (e.g. 100Ah) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batteryNoController,
                      decoration: const InputDecoration(
                        labelText: 'Battery Serial Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _warrantyController,
                      decoration: const InputDecoration(
                        labelText: 'Warranty (Months)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (code == 'tyres') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tyreBrandController,
                      decoration: const InputDecoration(
                        labelText: 'Tyre Brand *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tyreSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Tyre Size *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tyreQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity Fitted *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ] else if (code == 'maintenance') ...[
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Maintenance Category *',
                  border: OutlineInputBorder(),
                ),
                items: expenseProvider.categories.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id is int
                        ? c.id as int
                        : int.tryParse(c.id.toString()) ?? 0,
                    child: Text(c.name),
                  );
                }).toList(),
                onChanged: _onCategoryChanged,
                validator: (val) =>
                    val == null ? 'Please select category' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubCategory,
                decoration: const InputDecoration(
                  labelText: 'Sub-Category *',
                  border: OutlineInputBorder(),
                ),
                items: expenseProvider.subCategories.map((sc) {
                  return DropdownMenuItem<String>(
                    value: sc.name,
                    child: Text(sc.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubCategory = val),
                validator: (val) =>
                    val == null ? 'Please select sub-category' : null,
              ),
            ] else if (code == 'fuel') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fuelQtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity (Litres) *',
                        border: OutlineInputBorder(),
                        suffixText: 'L',
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fuelRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rate (₹ / Litre) *',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ] else if (code == 'salary') ...[
              TextFormField(
                controller: _staffNameController,
                decoration: const InputDecoration(
                  labelText: 'Staff / Driver Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryMonthController,
                decoration: const InputDecoration(
                  labelText: 'Salary Month (e.g. October 2026) *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Notes / Remarks',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: expenseProvider.isLoading ? null : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: expenseProvider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Submit Expense Record',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
