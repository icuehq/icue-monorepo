import 'dart:async';

import 'package:auth/src/providers/parent_auth_provider.dart';
import 'package:auth/src/ui/parent/parent_auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

const _resendSeconds = 60;

class ParentOtpPage extends StatefulWidget {
  const ParentOtpPage({required this.mobile, super.key});

  final String mobile;

  @override
  State<ParentOtpPage> createState() => _ParentOtpPageState();
}

class _ParentOtpPageState extends State<ParentOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  bool get _canResend => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    final outcome = await context.read<ParentAuthProvider>().requestOtp(
      widget.mobile,
    );
    if (!mounted || outcome == null) return;
    final message = outcome.message;
    if (message != null) IcueToast.success(context, message);
    _startTimer();
  }

  Future<void> _verify() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    // The router redirects to the student list once the session exists.
    await context.read<ParentAuthProvider>().login(widget.mobile, _otp.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final busy = context.watch<ParentAuthProvider>().busy;
    final primary = Theme.of(context).colorScheme.primary;
    return ParentAuthScaffold(
      title: l10n.otpVerify,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              SvgPicture.asset(
                'packages/auth/assets/parent/otp.svg',
                height: 200,
              ),
              const SizedBox(height: 40),
              Text.rich(
                TextSpan(
                  text: '${l10n.otpSentMessage} ',
                  children: [
                    TextSpan(
                      text: '(+91) ${widget.mobile}',
                      style: TextStyle(color: primary),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              IcueTextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                hintText: l10n.otp,
                validator: (value) => (value == null || value.isEmpty)
                    ? l10n.pleaseEnterOtp
                    : null,
                onFieldSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 10),
              Row(
                spacing: 16,
                children: [
                  Text(
                    l10n.didNotGetOtp,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IcueButton(
                    label: _canResend
                        ? l10n.resendCode
                        : '$_secondsLeft ${l10n.sec}',
                    variant: IcueButtonVariant.secondary,
                    size: IcueButtonSize.small,
                    onPressed: _canResend && !busy ? _resend : null,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              IcueButton(
                label: l10n.verify,
                isFullWidth: true,
                isLoading: busy,
                onPressed: busy ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
