import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/drivers/widgets/driver_license_info_form.dart';
import 'package:icueadmin/features/drivers/widgets/driver_personal_info_form.dart';
import 'package:provider/provider.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key, this.driver});

  final Driver? driver;

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _dobController;
  late final TextEditingController _dojController;
  late final TextEditingController _mobileController;
  late final TextEditingController _altMobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _aadharController;

  late final TextEditingController _licenseNumberController;
  late final TextEditingController _licenseIssueDateController;
  late final TextEditingController _licenseExpiryDateController;
  late final TextEditingController _experienceController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _pincodeController;

  DateTime? _dob;
  DateTime? _doj;
  DateTime? _licenceIssueDate;
  DateTime? _licenceExpiryDate;

  bool get isEditing => widget.driver != null;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;

    _firstNameController = TextEditingController(text: d?.firstName ?? '');
    _middleNameController = TextEditingController(text: d?.middleName ?? '');
    _lastNameController = TextEditingController(text: d?.lastName ?? '');
    _dobController = TextEditingController(text: d?.dateOfBirth ?? '');
    _dojController = TextEditingController(text: d?.dateOfJoining ?? '');
    _mobileController = TextEditingController(text: '${d?.mobile ?? ''}');
    _altMobileController = TextEditingController(text: '${d?.alternateNumber ?? ''}');
    _emailController = TextEditingController(text: d?.email ?? '');
    _aadharController = TextEditingController(text: d?.idType ?? '');

    _licenseNumberController = TextEditingController(text: d?.licenceNumber ?? '');
    _licenseIssueDateController = TextEditingController(text: d?.licenceIssuedDate ?? '');
    _licenseExpiryDateController = TextEditingController(text: d?.licenceExpiryDate ?? '');
    _experienceController = TextEditingController(text: '${d?.drivingExperience ?? ''}');
    _addressLine1Controller = TextEditingController(text: d?.address.line1 ?? '');
    _addressLine2Controller = TextEditingController(text: d?.address.line2 ?? '');
    _cityController = TextEditingController(text: d?.city ?? '');
    _stateController = TextEditingController(text: d?.state ?? '');
    _countryController = TextEditingController(text: d?.country ?? 'India');
    _pincodeController = TextEditingController(text: '${d?.pincode ?? ''}');

    _dob = AppDateUtils.tryParseDate(d?.dateOfBirth);
    _doj = AppDateUtils.tryParseDate(d?.dateOfJoining);
    _licenceIssueDate = AppDateUtils.tryParseDate(d?.licenceIssuedDate);
    _licenceExpiryDate = AppDateUtils.tryParseDate(d?.licenceExpiryDate);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _dojController.dispose();
    _mobileController.dispose();
    _altMobileController.dispose();
    _emailController.dispose();
    _aadharController.dispose();

    _licenseNumberController.dispose();
    _licenseIssueDateController.dispose();
    _licenseExpiryDateController.dispose();
    _experienceController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
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
      firstDate: DateTime(1950),
      lastDate: allowFuture ? DateTime(2050) : now,
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _onSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final request = AddDriverRequest(
      id: widget.driver?.id,
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      mobile: int.tryParse(_mobileController.text.trim()) ?? _mobileController.text.trim(),
      alternateNumber: int.tryParse(_altMobileController.text.trim()),
      email: _emailController.text.trim(),
      idType: _aadharController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      dateOfJoining: _dojController.text.trim(),
      licenceNumber: _licenseNumberController.text.trim(),
      drivingExperience: _experienceController.text.trim(),
      licenceIssuedDate: _licenseIssueDateController.text.trim(),
      licenceExpiryDate: _licenseExpiryDateController.text.trim(),
      address: Address(
        line1: _addressLine1Controller.text.trim(),
        line2: _addressLine2Controller.text.trim(),
      ),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      pincode: _pincodeController.text.trim(),
    );

    final provider = context.read<DriverProvider>();
    final success = isEditing
        ? await provider.updateDriver(request)
        : await provider.addDriver(request);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Driver updated successfully'
                : 'Driver created successfully',
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
    final provider = context.watch<DriverProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Update Driver' : 'Add Driver'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DriverPersonalInfoForm(
                  firstNameController: _firstNameController,
                  middleNameController: _middleNameController,
                  lastNameController: _lastNameController,
                  dobController: _dobController,
                  dojController: _dojController,
                  mobileController: _mobileController,
                  altMobileController: _altMobileController,
                  emailController: _emailController,
                  aadharController: _aadharController,
                  onSelectDob: () => _selectDate(
                    context: context,
                    initialDate: _dob,
                    allowFuture: false,
                    onSelected: (date) {
                      setState(() {
                        _dob = date;
                        _dobController.text = AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                  onSelectDoj: () => _selectDate(
                    context: context,
                    initialDate: _doj,
                    allowFuture: false,
                    onSelected: (date) {
                      setState(() {
                        _doj = date;
                        _dojController.text = AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                DriverLicenseInfoForm(
                  licenseNumberController: _licenseNumberController,
                  licenseIssueDateController: _licenseIssueDateController,
                  licenseExpiryDateController: _licenseExpiryDateController,
                  experienceController: _experienceController,
                  addressLine1Controller: _addressLine1Controller,
                  addressLine2Controller: _addressLine2Controller,
                  cityController: _cityController,
                  stateController: _stateController,
                  countryController: _countryController,
                  pincodeController: _pincodeController,
                  onSelectIssueDate: () => _selectDate(
                    context: context,
                    initialDate: _licenceIssueDate,
                    allowFuture: false,
                    onSelected: (date) {
                      setState(() {
                        _licenceIssueDate = date;
                        _licenseIssueDateController.text =
                            AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                  onSelectExpiryDate: () => _selectDate(
                    context: context,
                    initialDate: _licenceExpiryDate,
                    allowFuture: true,
                    onSelected: (date) {
                      setState(() {
                        _licenceExpiryDate = date;
                        _licenseExpiryDateController.text =
                            AppDateUtils.formatDate(date);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: provider.isLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Update Driver' : 'Add Driver',
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
