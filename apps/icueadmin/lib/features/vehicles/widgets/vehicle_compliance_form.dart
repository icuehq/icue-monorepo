import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VehicleComplianceForm extends StatelessWidget {
  const VehicleComplianceForm({
    super.key,
    required this.dateOfRegController,
    required this.rtaOfcController,
    required this.claimedMileageController,
    required this.expectedMileageController,
    required this.fireExtNameController,
    required this.fireExtInstallDateController,
    required this.fireExtExpiryDateController,
    required this.firstAidDetailsController,
    required this.firstAidExpiryDateController,
    required this.onSelectRegDate,
    required this.onSelectFireExtInstallDate,
    required this.onSelectFireExtExpiryDate,
    required this.onSelectFirstAidExpiryDate,
    required this.drivers,
    required this.selectedDriver,
    required this.onDriverSelected,
  });

  final TextEditingController dateOfRegController;
  final TextEditingController rtaOfcController;
  final TextEditingController claimedMileageController;
  final TextEditingController expectedMileageController;
  final TextEditingController fireExtNameController;
  final TextEditingController fireExtInstallDateController;
  final TextEditingController fireExtExpiryDateController;
  final TextEditingController firstAidDetailsController;
  final TextEditingController firstAidExpiryDateController;
  final VoidCallback onSelectRegDate;
  final VoidCallback onSelectFireExtInstallDate;
  final VoidCallback onSelectFireExtExpiryDate;
  final VoidCallback onSelectFirstAidExpiryDate;
  final List<Driver> drivers;
  final Driver? selectedDriver;
  final ValueChanged<Driver?> onDriverSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compliance & Driver Assignment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSelectRegDate,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: dateOfRegController,
                    hintText: 'Date of Registration',
                    prefixIcon: const Icon(Icons.event_note_outlined, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: rtaOfcController,
                hintText: 'RTA Office (e.g. Khairatabad)',
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: claimedMileageController,
                hintText: 'Company Mileage (km/l)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: expectedMileageController,
                hintText: 'Expected Mileage (km/l)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSearchableAutocomplete<Driver>(
          label: 'Assigned Driver',
          hintText: 'Search driver by name or phone...',
          initialSelection: selectedDriver,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase();
            if (query.isEmpty) return drivers;
            return drivers.where((d) {
              return d.fullName.toLowerCase().contains(query) ||
                  '${d.mobile ?? ''}'.contains(query);
            });
          },
          displayStringForOption: (driver) =>
              '${driver.fullName} (${driver.mobile ?? 'No phone'})',
          onSelected: onDriverSelected,
        ),
        const SizedBox(height: 16),
        const Text(
          'Safety Equipment',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: fireExtNameController,
          hintText: 'Fire Extinguisher Identifier / Serial',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSelectFireExtInstallDate,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: fireExtInstallDateController,
                    hintText: 'Install Date',
                    prefixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onSelectFireExtExpiryDate,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: fireExtExpiryDateController,
                    hintText: 'Expiry Date',
                    prefixIcon: const Icon(Icons.event_busy_outlined, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: firstAidDetailsController,
          hintText: 'First Aid Kit Items / Notes',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onSelectFirstAidExpiryDate,
          child: IgnorePointer(
            child: AppTextField(
              controller: firstAidExpiryDateController,
              hintText: 'First Aid Kit Expiry Date',
              prefixIcon: const Icon(Icons.medical_services_outlined, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
