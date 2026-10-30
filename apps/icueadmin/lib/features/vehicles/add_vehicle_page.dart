import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/vehicles/widgets/vehicle_basic_info_form.dart';
import 'package:icueadmin/features/vehicles/widgets/vehicle_compliance_form.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key, this.vehicle});

  final VehicleData? vehicle;

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numberController;
  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _capacityController;
  late final TextEditingController _colourController;
  late final TextEditingController _chassisController;
  late final TextEditingController _engineController;

  late final TextEditingController _dateOfRegController;
  late final TextEditingController _rtaOfcController;
  late final TextEditingController _claimedMileageController;
  late final TextEditingController _expectedMileageController;
  late final TextEditingController _fireExtNameController;
  late final TextEditingController _fireExtInstallDateController;
  late final TextEditingController _fireExtExpiryDateController;
  late final TextEditingController _firstAidDetailsController;
  late final TextEditingController _firstAidExpiryDateController;

  String _fuelType = 'Diesel';
  bool _isAc = false;
  Driver? _selectedDriver;

  DateTime? _dateOfReg;
  DateTime? _fireExtInstallDate;
  DateTime? _fireExtExpiryDate;
  DateTime? _firstAidExpiryDate;

  bool get isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;

    _numberController = TextEditingController(text: v?.number ?? '');
    _makeController = TextEditingController(text: v?.make ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController = TextEditingController(text: v?.year ?? '');
    _capacityController = TextEditingController(text: '${v?.capacity ?? ''}');
    _colourController = TextEditingController(text: v?.colour ?? '');
    _chassisController = TextEditingController(text: v?.chasisNumber ?? '');
    _engineController = TextEditingController(text: v?.engineNumber ?? '');

    _dateOfRegController = TextEditingController(text: v?.dateOfReg ?? '');
    _rtaOfcController = TextEditingController(text: v?.rtaOfcName ?? '');
    _claimedMileageController =
        TextEditingController(text: '${v?.companyClaimedMileage ?? ''}');
    _expectedMileageController =
        TextEditingController(text: '${v?.actualExpectedMileage ?? ''}');
    _fireExtNameController = TextEditingController(text: v?.fireExtName ?? '');
    _fireExtInstallDateController =
        TextEditingController(text: v?.fireExtInstallDate ?? '');
    _fireExtExpiryDateController =
        TextEditingController(text: v?.fireExtExpiryDate ?? '');

    final firstAid =
        v != null && v.firstAidKit.isNotEmpty ? v.firstAidKit.first : null;
    _firstAidDetailsController =
        TextEditingController(text: firstAid?.medicineDetails ?? '');
    _firstAidExpiryDateController =
        TextEditingController(text: firstAid?.medicineExpiryDate ?? '');

    _fuelType = v?.fuelType ?? 'Diesel';
    _isAc = v?.airCondition?.toLowerCase() == 'yes';

    _dateOfReg = AppDateUtils.tryParseDate(v?.dateOfReg);
    _fireExtInstallDate = AppDateUtils.tryParseDate(v?.fireExtInstallDate);
    _fireExtExpiryDate = AppDateUtils.tryParseDate(v?.fireExtExpiryDate);
    _firstAidExpiryDate =
        AppDateUtils.tryParseDate(firstAid?.medicineExpiryDate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DriverProvider>().fetchDrivers();
      }
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _capacityController.dispose();
    _colourController.dispose();
    _chassisController.dispose();
    _engineController.dispose();

    _dateOfRegController.dispose();
    _rtaOfcController.dispose();
    _claimedMileageController.dispose();
    _expectedMileageController.dispose();
    _fireExtNameController.dispose();
    _fireExtInstallDateController.dispose();
    _fireExtExpiryDateController.dispose();
    _firstAidDetailsController.dispose();
    _firstAidExpiryDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({
    required BuildContext context,
    required DateTime? initialDate,
    required bool allowFuture,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(1970),
      lastDate: allowFuture ? DateTime(2050) : now,
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _onSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<VehicleProvider>();

    final firstAidKits = _firstAidDetailsController.text.trim().isNotEmpty
        ? [
            FirstAidKit(
              medicineDetails: _firstAidDetailsController.text.trim(),
              medicineExpiryDate: _firstAidExpiryDateController.text.trim(),
            ),
          ]
        : <FirstAidKit>[];

    final request = AddVehicleRequest(
      id: widget.vehicle?.id,
      number: _numberController.text.trim().toUpperCase(),
      fuelType: _fuelType,
      make: _makeController.text.trim(),
      model: _modelController.text.trim(),
      year: _yearController.text.trim(),
      capacity: _capacityController.text.trim(),
      colour: _colourController.text.trim(),
      chasisNumber: _chassisController.text.trim(),
      engineNumber: _engineController.text.trim(),
      airCondition: _isAc ? 'Yes' : 'No',
      dateOfReg: _dateOfRegController.text.trim(),
      rtaOfcName: _rtaOfcController.text.trim(),
      companyClaimedMileage:
          num.tryParse(_claimedMileageController.text.trim()) ?? 0,
      actualExpectedMileage:
          num.tryParse(_expectedMileageController.text.trim()) ?? 0,
      driverId: _selectedDriver?.id ?? widget.vehicle?.driverId,
      driverName: _selectedDriver?.fullName ?? widget.vehicle?.driverName,
      driverNumber: _selectedDriver?.mobile ?? widget.vehicle?.driverNumber,
      fireExtName: _fireExtNameController.text.trim(),
      fireExtInstallDate: _fireExtInstallDateController.text.trim(),
      fireExtExpiryDate: _fireExtExpiryDateController.text.trim(),
      firstAidKit: firstAidKits,
    );

    final success = isEditing
        ? await provider.updateVehicle(request)
        : await provider.addVehicle(request);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Vehicle updated successfully'
                : 'Vehicle added to fleet successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Operation failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final driverProvider = context.watch<DriverProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Update Vehicle' : 'Add Vehicle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VehicleBasicInfoForm(
                  numberController: _numberController,
                  makeController: _makeController,
                  modelController: _modelController,
                  yearController: _yearController,
                  capacityController: _capacityController,
                  colourController: _colourController,
                  chassisController: _chassisController,
                  engineController: _engineController,
                  selectedFuelType: _fuelType,
                  onFuelTypeChanged: (val) {
                    if (val != null) setState(() => _fuelType = val);
                  },
                  isAc: _isAc,
                  onAcChanged: (val) => setState(() => _isAc = val),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                VehicleComplianceForm(
                  dateOfRegController: _dateOfRegController,
                  rtaOfcController: _rtaOfcController,
                  claimedMileageController: _claimedMileageController,
                  expectedMileageController: _expectedMileageController,
                  fireExtNameController: _fireExtNameController,
                  fireExtInstallDateController: _fireExtInstallDateController,
                  fireExtExpiryDateController: _fireExtExpiryDateController,
                  firstAidDetailsController: _firstAidDetailsController,
                  firstAidExpiryDateController: _firstAidExpiryDateController,
                  onSelectRegDate: () => _selectDate(
                    context: context,
                    initialDate: _dateOfReg,
                    allowFuture: false,
                    onSelected: (date) {
                      setState(() {
                        _dateOfReg = date;
                        _dateOfRegController.text =
                            AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                  onSelectFireExtInstallDate: () => _selectDate(
                    context: context,
                    initialDate: _fireExtInstallDate,
                    allowFuture: false,
                    onSelected: (date) {
                      setState(() {
                        _fireExtInstallDate = date;
                        _fireExtInstallDateController.text =
                            AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                  onSelectFireExtExpiryDate: () => _selectDate(
                    context: context,
                    initialDate: _fireExtExpiryDate,
                    allowFuture: true,
                    onSelected: (date) {
                      setState(() {
                        _fireExtExpiryDate = date;
                        _fireExtExpiryDateController.text =
                            AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                  onSelectFirstAidExpiryDate: () => _selectDate(
                    context: context,
                    initialDate: _firstAidExpiryDate,
                    allowFuture: true,
                    onSelected: (date) {
                      setState(() {
                        _firstAidExpiryDate = date;
                        _firstAidExpiryDateController.text =
                            AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                  drivers: driverProvider.drivers,
                  selectedDriver: _selectedDriver,
                  onDriverSelected: (d) => setState(() => _selectedDriver = d),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: vehicleProvider.isLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: vehicleProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Update Vehicle' : 'Add Vehicle',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
