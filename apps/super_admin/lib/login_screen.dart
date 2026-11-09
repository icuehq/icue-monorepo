import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:face_enrollment/face_enrollment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // The router automatically redirects to the student directory once signed in.
      await authProvider.loginWithPassword(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    _buildBrandHeader(),

                    const SizedBox(height: 28),

                    // Glass Login Card
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      borderColor: context.scheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCardHeader(),
                              const SizedBox(height: 22),

                              // Username Input
                              AppTextField(
                                controller: _usernameController,
                                label: 'School Username',
                                icon: Icons.account_circle_outlined,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                autocorrect: false,
                                enableSuggestions: false,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter school username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Input
                              AppTextField(
                                controller: _passwordController,
                                obscureText: true,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                autofillHints: const [AutofillHints.password],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Error Message Alert
                              if (authProvider.errorMessage != null)
                                _buildErrorAlert(authProvider.errorMessage!),

                              // Submit Login Button
                              CustomButton(
                                text: 'SIGN IN TO PORTAL',
                                isLoading: authProvider.isLoading,
                                onPressed: _handleLogin,
                                icon: Icons.login_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Security Footer
                    _buildSecurityFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: context.scheme.primary.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset('assets/images/logo.webp', fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),
        Text(
          'iCue Super Admin',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
            color: context.scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Face Biometrics & Student Identification Portal',
          style: TextStyle(
            fontSize: 12.5,
            color: context.scheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCardHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.fingerprint_rounded,
            color: context.scheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRATOR SIGN IN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: context.scheme.onSurface,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Enter institutional credentials to continue',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorAlert(String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.scheme.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: context.scheme.error,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: context.scheme.onSurface.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Text(
          'Protected by Biometric Security Gateway · iCue',
          style: TextStyle(
            fontSize: 11.5,
            color: context.scheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
