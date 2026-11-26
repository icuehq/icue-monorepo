import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

class LoginFormCard extends StatelessWidget {
  const LoginFormCard({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.error,
    required this.isLoading,
    required this.onSubmit,
    required this.isWide,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String? error;
  final bool isLoading;
  final VoidCallback onSubmit;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      color: scheme.surface,
      child: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 24),
        child: AutofillGroup(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isWide) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: scheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'BRANCH ADMIN',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please enter your username and password to continue.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to manage your school branch.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                IcueTextField(
                  controller: usernameController,
                  label: 'Username',
                  hintText: 'Enter your username',
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter username'
                      : null,
                ),
                const SizedBox(height: 16),
                IcueTextField(
                  controller: passwordController,
                  obscureText: true,
                  label: 'Password',
                  hintText: 'Enter your password',
                  icon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmit(),
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter password'
                      : null,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  _LoginErrorBanner(error: error!, scheme: scheme),
                ],
                const SizedBox(height: 24),
                IcueButton(
                  label: 'SIGN IN',
                  size: IcueButtonSize.large,
                  isLoading: isLoading,
                  onPressed: onSubmit,
                  trailingIcon: Icons.login_rounded,
                  isFullWidth: true,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only authorized branch administrators can sign in. If you need help or forgot your password, please contact your school administrator.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Secure login for school branch staff',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.error, required this.scheme});

  final String error;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: scheme.error,
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
}
