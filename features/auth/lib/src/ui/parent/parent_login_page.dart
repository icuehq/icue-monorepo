import 'package:auth/src/providers/parent_auth_provider.dart';
import 'package:auth/src/services/parent_auth_service.dart';
import 'package:auth/src/ui/parent/not_registered_dialog.dart';
import 'package:auth/src/ui/parent/parent_auth_routes.dart';
import 'package:auth/src/ui/parent/parent_auth_scaffold.dart';
import 'package:auth/src/utils/indian_phone_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

class ParentLoginPage extends StatefulWidget {
  const ParentLoginPage({super.key});

  @override
  State<ParentLoginPage> createState() => _ParentLoginPageState();
}

class _ParentLoginPageState extends State<ParentLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobile = TextEditingController();

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final outcome = await context.read<ParentAuthProvider>().requestOtp(
      _mobile.text,
    );
    if (!mounted || outcome == null) return;
    if (outcome.result == ParentOtpResult.notRegistered) {
      await showNotRegisteredDialog(context);
      return;
    }
    final message = outcome.message;
    if (message != null) IcueToast.success(context, message);
    await context.push(ParentAuthRoutes.otp, extra: _mobile.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final busy = context.watch<ParentAuthProvider>().busy;
    return ParentAuthScaffold(
      title: l10n.login,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(child: Image.asset(IcueAssets.logo, height: 50)),
            const SizedBox(height: 20),
            Center(
              child: SvgPicture.asset(
                'packages/auth/assets/parent/login.svg',
                height: 150,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              l10n.enterPhoneNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            IcueTextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              validator: IndianPhoneValidator.validate,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              prefixText: '+91 ',
              hintText: l10n.mobileNumber,
              suffixIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(
                  'packages/auth/assets/parent/phone.svg',
                ),
              ),
              onFieldSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 5),
            Text(
              l10n.securingYourPersonalInformationIsOurPriority,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            IcueButton(
              label: l10n.sendOtp,
              isFullWidth: true,
              isLoading: busy,
              onPressed: busy ? null : _sendOtp,
            ),
          ],
        ),
      ),
    );
  }
}
