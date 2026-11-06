import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
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
    required this.countries,
    required this.places,
    required this.onCountryChanged,
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
  final List<Place> countries;
  final List<Place> places;
  final ValueChanged<Place> onCountryChanged;
  final VoidCallback onSelectIssueDate;
  final VoidCallback onSelectExpiryDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'License & Address Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                icon: Icons.card_membership_outlined,
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
                    icon: Icons.calendar_today_outlined,
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
                    icon: Icons.event_busy_outlined,
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
              child: AppTextField(controller: cityController, hintText: 'City'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlaceDropdown(
                label: 'State',
                controller: stateController,
                places: places,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PlaceDropdown(
                label: 'Country',
                controller: countryController,
                places: countries,
                onChanged: onCountryChanged,
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

/// Picks a place by name into [controller]; empty until the list loads.
class _PlaceDropdown extends StatelessWidget {
  const _PlaceDropdown({
    required this.label,
    required this.controller,
    required this.places,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final List<Place> places;
  final ValueChanged<Place> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = places.any((p) => p.name == controller.text)
        ? controller.text
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$current-${places.length}'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final place in places)
          DropdownMenuItem(value: place.name, child: Text(place.name)),
      ],
      onChanged: places.isEmpty
          ? null
          : (name) {
              if (name == null) return;
              controller.text = name;
              onChanged(places.firstWhere((p) => p.name == name));
            },
    );
  }
}
