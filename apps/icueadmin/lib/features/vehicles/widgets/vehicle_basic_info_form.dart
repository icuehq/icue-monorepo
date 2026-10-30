import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VehicleBasicInfoForm extends StatelessWidget {
  const VehicleBasicInfoForm({
    super.key,
    required this.numberController,
    required this.makeController,
    required this.modelController,
    required this.yearController,
    required this.capacityController,
    required this.colourController,
    required this.chassisController,
    required this.engineController,
    required this.selectedFuelType,
    required this.onFuelTypeChanged,
    required this.isAc,
    required this.onAcChanged,
  });

  final TextEditingController numberController;
  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final TextEditingController capacityController;
  final TextEditingController colourController;
  final TextEditingController chassisController;
  final TextEditingController engineController;
  final String selectedFuelType;
  final ValueChanged<String?> onFuelTypeChanged;
  final bool isAc;
  final ValueChanged<bool> onAcChanged;

  static const _fuelTypes = ['Diesel', 'Petrol', 'CNG', 'Electric'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Specifications',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: numberController,
          hintText: 'Vehicle Number * (e.g. AP28TV1234)',
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Vehicle number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: makeController,
                hintText: 'Make * (e.g. Tata)',
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Make is required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: modelController,
                hintText: 'Model (e.g. Starbus)',
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
                controller: yearController,
                hintText: 'Year * (e.g. 2022)',
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Year is required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: capacityController,
                hintText: 'Seating Capacity *',
                keyboardType: TextInputType.number,
                maxLength: 3,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Capacity is required'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFuelType,
                    isExpanded: true,
                    items: _fuelTypes.map((f) {
                      return DropdownMenuItem(value: f, child: Text(f));
                    }).toList(),
                    onChanged: onFuelTypeChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: colourController,
                hintText: 'Colour',
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
                controller: chassisController,
                hintText: 'Chassis Number',
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: engineController,
                hintText: 'Engine Number',
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Air Conditioned (AC):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Switch(value: isAc, onChanged: onAcChanged),
          ],
        ),
      ],
    );
  }
}
