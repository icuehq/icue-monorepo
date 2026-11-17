import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:school_connect/src/providers/complaints_provider.dart';
import 'package:school_connect/src/ui/routing/school_connect_router.dart';

class PostComplaintPage extends StatefulWidget {
  const PostComplaintPage({super.key});

  @override
  State<PostComplaintPage> createState() => _PostComplaintPageState();
}

class _PostComplaintPageState extends State<PostComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _query = TextEditingController();
  int? _type;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<ComplaintsProvider>().loadTypes(),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final l10n = ParentLocalizations.of(context);
    final posted = await context.read<ComplaintsProvider>().post(
      type: _type!,
      query: _query.text.trim(),
    );
    if (!mounted || !posted) return;
    IcueToast.success(context, l10n.querySubmitted);
    _query.clear();
    setState(() => _type = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<ComplaintsProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.postComplaint),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(SchoolConnectRoutes.complaintsPath),
        label: Text(l10n.history, style: const TextStyle(fontSize: 18)),
      ),
      body: IcueSheetBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              IcueDropdown<int>(
                hintText: l10n.selectComplaintType,
                value: _type,
                items: [
                  for (final type in provider.types)
                    DropdownMenuItem(
                      value: type.type,
                      child: Text(type.description),
                    ),
                ],
                validator: (v) =>
                    v == null ? l10n.pleaseSelectComplaintType : null,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 16),
              IcueTextField(
                controller: _query,
                minLines: 5,
                maxLines: 5,
                hintText: l10n.writeYourQuery,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.pleaseWriteYourQuery
                    : null,
              ),
              const SizedBox(height: 30),
              IcueButton(
                label: l10n.submit,
                isFullWidth: true,
                size: IcueButtonSize.large,
                isLoading: provider.loading,
                onPressed: provider.loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
