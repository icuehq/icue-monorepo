import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerifyOtpForm extends StatefulWidget {
  const VerifyOtpForm({
    required this.username,
    required this.otpController,
    required this.primaryColor,
    required this.onVerify,
    required this.onBack,
    required this.isLoading,
    this.errorMessage,
    super.key,
  });

  final String username;
  final TextEditingController otpController;
  final Color primaryColor;
  final VoidCallback onVerify;
  final VoidCallback onBack;
  final bool isLoading;
  final String? errorMessage;

  @override
  State<VerifyOtpForm> createState() => _VerifyOtpFormState();
}

class _VerifyOtpFormState extends State<VerifyOtpForm> {
  String? _localError;
  String? _lastServerErrorMessage;

  @override
  void initState() {
    super.initState();
    _lastServerErrorMessage = widget.errorMessage;
  }

  @override
  void didUpdateWidget(covariant VerifyOtpForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      _lastServerErrorMessage = widget.errorMessage;
    }
  }

  void _handleVerify() {
    final otp = widget.otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _localError = 'Please enter OTP');
      return;
    }
    if (otp.length < 4) {
      setState(() => _localError = 'Please enter a valid OTP');
      return;
    }
    setState(() {
      _localError = null;
      _lastServerErrorMessage = null;
    });
    widget.onVerify();
  }

  void _onChanged(String _) {
    if (_localError != null || _lastServerErrorMessage != null) {
      setState(() {
        _localError = null;
        _lastServerErrorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveError = _localError ?? _lastServerErrorMessage;

    return Column(
      children: [
        Text(
          'Verify OTP',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'OTP sent to ${widget.username}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: widget.otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          hintText: 'Enter OTP',
          errorText: effectiveError,
          icon: Icons.lock_clock_outlined,
          onChanged: _onChanged,
          onFieldSubmitted: (_) => _handleVerify(),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Verify & Login',
          size: AppButtonSize.large,
          isFullWidth: true,
          isLoading: widget.isLoading,
          onPressed: widget.isLoading ? null : _handleVerify,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Change Mobile Number',
          variant: AppButtonVariant.ghost,
          leadingIcon: Icons.arrow_back,
          onPressed: widget.isLoading ? null : widget.onBack,
        ),
      ],
    );
  }
}
