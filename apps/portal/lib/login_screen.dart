import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';

const _branchAdminRole = 'Branch_Admin';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _roleError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    setState(() => _roleError = null);
    final success = await authProvider.loginWithPassword(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      source: 'web',
    );
    if (!success) return;
    final isBranchAdmin =
        authProvider.user?.roles.any((role) => role.name == _branchAdminRole) ??
        false;
    if (!isBranchAdmin) {
      await authProvider.logout();
      if (mounted) {
        setState(() => _roleError = 'This portal is for branch admins only.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final error = _roleError ?? authProvider.errorMessage;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/images/logo.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'iCue Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              IcueTextField(
                                controller: _usernameController,
                                label: 'Username',
                                icon: Icons.account_circle_outlined,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                autocorrect: false,
                                enableSuggestions: false,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Please enter username'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              IcueTextField(
                                controller: _passwordController,
                                obscureText: true,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                autofillHints: const [AutofillHints.password],
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Please enter password'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: scheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              IcueButton(
                                label: 'SIGN IN',
                                isLoading: authProvider.isLoading,
                                onPressed: _handleLogin,
                                leadingIcon: Icons.login_rounded,
                                isFullWidth: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
