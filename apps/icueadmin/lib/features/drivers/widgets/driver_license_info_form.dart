import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DriverLicenseInfoForm extends StatelessWidget {
  const DriverLicenseInfoForm({
    super.key,
    required this.licenseNumberController,
    required this.licenseIssueDateController,
    required this.licenseExpiryDateController,
    required this.experienceController,
    required this.addressLine1Controller,
    required this.addressLine2Controller,
    required this.cityController,
    required this.stateController,
    required this.countryController,
    required this.pincodeController,
    required this.onSelectIssueDate,
    required this.onSelectExpiryDate,
  });

  final TextEditingController licenseNumberController;
  final TextEditingController licenseIssueDateController;
  final TextEditingController licenseExpiryDateController;
  final TextEditingController experienceController;
  final TextEditingController addressLine1Controller;
  final TextEditingController addressLine2Controller;
  final TextEditingController cityController;
  final TextEditingController stateController;
  final TextEditingController countryController;
  final TextEditingController pincodeController;
  final VoidCallback onSelectIssueDate;
  final VoidCallback onSelectExpiryDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'License & Address Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: licenseNumberController,
                hintText: 'License Number',
                maxLength: 20,
                prefixIcon: const Icon(Icons.card_membership_outlined, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: experienceController,
                hintText: 'Exp (Yrs)',
                keyboardType: TextInputType.number,
                maxLength: 2,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSelectIssueDate,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: licenseIssueDateController,
                    hintText: 'Issue Date',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onSelectExpiryDate,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: licenseExpiryDateController,
                    hintText: 'Expiry Date',
                    prefixIcon: const Icon(Icons.event_busy_outlined, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: addressLine1Controller,
          hintText: 'Address Line 1 *',
          keyboardType: TextInputType.streetAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Address Line 1 is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: addressLine2Controller,
          hintText: 'Address Line 2',
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: cityController,
                hintText: 'City',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: stateController,
                hintText: 'State',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: countryController,
                hintText: 'Country',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: pincodeController,
                hintText: 'Pincode',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
