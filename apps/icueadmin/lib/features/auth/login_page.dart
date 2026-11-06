import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/auth/widgets/request_otp_form.dart';
import 'package:icueadmin/features/auth/widgets/verify_otp_form.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  late final TextEditingController _otpController;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Reads the SMS OTP through Android's user-consent prompt and signs in.
      _otpController =
          OTPTextEditController(
            codeLength: 5,
            onCodeReceive: (code) {
              FocusManager.instance.primaryFocus?.unfocus();
              context.read<AuthProvider>().login(
                username: _usernameController.text,
                password: code,
              );
            },
            otpInteractor: OTPInteractor(),
          )..startListenUserConsent(
            (code) => RegExp(r'(\d{5})').stringMatch(code ?? '') ?? '',
            strategies: [],
          );
    } else {
      _otpController = TextEditingController();
    }
  }

  @override
  void dispose() {
    final otp = _otpController;
    if (otp is OTPTextEditController) otp.stopListen();
    _usernameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Background illustration
          Positioned.fill(
            child: Image.asset(
              'assets/login_bg.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // Main scrollable content
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),

                      // App Logo
                      Image.asset(
                        'assets/logo.png',
                        height: 64,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Text(
                          'iCue',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // App Subtitle
                      Text(
                        'School Admin App',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Screen Stage
                      switch (vm.step) {
                        AuthStep.authenticated => const SizedBox.shrink(),
                        AuthStep.requestOtp => RequestOtpForm(
                          usernameController: _usernameController,
                          primaryColor: primaryColor,
                          isLoading: vm.isLoading,
                          errorMessage: vm.errorMessage,
                          onSubmit: () =>
                              vm.sendLoginOtp(_usernameController.text),
                        ),
                        AuthStep.verifyOtp => VerifyOtpForm(
                          username: vm.username,
                          otpController: _otpController,
                          primaryColor: primaryColor,
                          isLoading: vm.isLoading,
                          errorMessage: vm.errorMessage,
                          onVerify: () => vm.login(
                            username: _usernameController.text,
                            password: _otpController.text,
                          ),
                          onBack: () {
                            _otpController.clear();
                            vm.backToRequestOtp();
                          },
                        ),
                      },

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
