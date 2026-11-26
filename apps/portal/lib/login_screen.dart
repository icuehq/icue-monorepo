import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:portal/widgets/login_form_card.dart';
import 'package:portal/widgets/login_hero_pane.dart';
import 'package:portal/widgets/login_mobile_header.dart';
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
        setState(
          () => _roleError = 'This portal is for branch administrators only.',
        );
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= IcueBreakpoints.wide;
          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 5, child: LoginHeroPane(scheme: scheme)),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 36,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: LoginFormCard(
                          formKey: _formKey,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          error: error,
                          isLoading: authProvider.isLoading,
                          onSubmit: _handleLogin,
                          isWide: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 240,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.primary.withValues(alpha: 0.08),
                          scheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LoginMobileHeader(scheme: scheme),
                          const SizedBox(height: 24),
                          LoginFormCard(
                            formKey: _formKey,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            error: error,
                            isLoading: authProvider.isLoading,
                            onSubmit: _handleLogin,
                            isWide: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
