import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DriverPersonalInfoForm extends StatelessWidget {
  const DriverPersonalInfoForm({
    super.key,
    required this.firstNameController,
    required this.middleNameController,
    required this.lastNameController,
    required this.dobController,
    required this.dojController,
    required this.mobileController,
    required this.altMobileController,
    required this.emailController,
    required this.aadharController,
    required this.onSelectDob,
    required this.onSelectDoj,
  });

  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final TextEditingController lastNameController;
  final TextEditingController dobController;
  final TextEditingController dojController;
  final TextEditingController mobileController;
  final TextEditingController altMobileController;
  final TextEditingController emailController;
  final TextEditingController aadharController;
  final VoidCallback onSelectDob;
  final VoidCallback onSelectDoj;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: firstNameController,
          hintText: 'First Name *',
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'First name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: middleNameController,
                hintText: 'Middle Name',
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: lastNameController,
                hintText: 'Last Name',
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSelectDob,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: dobController,
                    hintText: 'Date of Birth',
                    prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onSelectDoj,
                child: IgnorePointer(
                  child: AppTextField(
                    controller: dojController,
                    hintText: 'Date of Joining',
                    prefixIcon: const Icon(Icons.event_outlined, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: mobileController,
          hintText: 'Mobile Number *',
          keyboardType: TextInputType.phone,
          maxLength: 10,
          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Mobile number is required';
            }
            if (v.trim().length != 10) {
              return 'Enter a valid 10-digit mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: altMobileController,
          hintText: 'Alternate Mobile Number',
          keyboardType: TextInputType.phone,
          maxLength: 10,
          prefixIcon: const Icon(Icons.phone_android_outlined, size: 20),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: emailController,
          hintText: 'Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.email_outlined, size: 20),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: aadharController,
          hintText: 'Aadhar Number (12 digits)',
          keyboardType: TextInputType.number,
          maxLength: 12,
          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }
}
