import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

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
    final hasError = effectiveError != null;

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
          autofocus: true,
          hintText: 'Enter OTP',
          errorText: effectiveError,
          prefixIcon: Icon(
            Icons.lock_clock_outlined,
            color: hasError
                ? Theme.of(context).colorScheme.error
                : widget.primaryColor,
            size: 22,
          ),
          onChanged: _onChanged,
          onFieldSubmitted: (_) => _handleVerify(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _handleVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verify & Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: widget.isLoading ? null : widget.onBack,
          icon: Icon(Icons.arrow_back, size: 16, color: widget.primaryColor),
          label: Text(
            'Change Mobile Number',
            style: TextStyle(
              color: widget.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
