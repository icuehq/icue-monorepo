import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RequestOtpForm extends StatefulWidget {
  const RequestOtpForm({
    required this.usernameController,
    required this.primaryColor,
    required this.onSubmit,
    required this.isLoading,
    this.errorMessage,
    super.key,
  });

  final TextEditingController usernameController;
  final Color primaryColor;
  final VoidCallback onSubmit;
  final bool isLoading;
  final String? errorMessage;

  @override
  State<RequestOtpForm> createState() => _RequestOtpFormState();
}

class _RequestOtpFormState extends State<RequestOtpForm> {
  String? _localError;
  String? _lastServerErrorMessage;

  @override
  void initState() {
    super.initState();
    _lastServerErrorMessage = widget.errorMessage;
  }

  @override
  void didUpdateWidget(covariant RequestOtpForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      _lastServerErrorMessage = widget.errorMessage;
    }
  }

  void _handleSubmit() {
    final validationError = IndianPhoneValidator.validate(
      widget.usernameController.text,
    );
    if (validationError != null) {
      setState(() => _localError = validationError);
      return;
    }
    final normalized = IndianPhoneValidator.normalize(
      widget.usernameController.text,
    );
    if (widget.usernameController.text != normalized) {
      widget.usernameController.text = normalized;
    }
    setState(() {
      _localError = null;
      _lastServerErrorMessage = null;
    });
    widget.onSubmit();
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
          'Login',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: widget.usernameController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          errorText: effectiveError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          hintText: 'Enter Mobile Number',
          prefixIcon: Icon(
            Icons.phone,
            color: hasError
                ? Theme.of(context).colorScheme.error
                : widget.primaryColor,
            size: 22,
          ),
          onChanged: _onChanged,
          onFieldSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _handleSubmit,
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
                    'Generate OTP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
