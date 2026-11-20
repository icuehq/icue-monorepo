import 'package:auth/auth.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:safehands/src/models/escort.dart';
import 'package:safehands/src/providers/escort_provider.dart';

/// Registers a permanent or temporary escort with a photo.
class AddEscortPage extends StatefulWidget {
  const AddEscortPage({super.key});

  @override
  State<AddEscortPage> createState() => _AddEscortPageState();
}

class _AddEscortPageState extends State<AddEscortPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _mobile = TextEditingController();
  final _from = TextEditingController(text: todayIST());
  final _to = TextEditingController();
  String? _type;
  IcuePickedFile? _photo;

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _mobile.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await pickFile(context);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = ParentLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final photo = _photo;
    if (photo == null) {
      IcueToast.error(context, l10n.pleaseUploadPhoto);
      return;
    }
    final temporary = _type == escortTemporary;
    final result = await context.read<EscortProvider>().add(
      type: _type!,
      name: _name.text.trim(),
      relation: _relation.text.trim(),
      mobile: _mobile.text,
      photo: photo,
      fromDate: temporary ? _from.text.toDateOrNull() : null,
      toDate: temporary ? _to.text.toDateOrNull() : null,
    );
    if (!mounted) return;
    if (result.ok) {
      IcueToast.success(context, l10n.escortSaved);
      context.pop();
    } else if (result.message != null) {
      IcueToast.error(context, result.message!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final busy = context.watch<EscortProvider>().loading;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.thisIsRequired : null;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.addEscort),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  IcueDropdown<String>(
                    label: l10n.type,
                    value: _type,
                    items: [
                      DropdownMenuItem(
                        value: escortPermanent,
                        child: Text(l10n.escortPermanent),
                      ),
                      DropdownMenuItem(
                        value: escortTemporary,
                        child: Text(l10n.escortTemporary),
                      ),
                    ],
                    validator: (v) => v == null ? l10n.thisIsRequired : null,
                    onChanged: (v) => setState(() => _type = v),
                  ),
                  const SizedBox(height: 16),
                  IcueTextField(
                    controller: _name,
                    label: l10n.name,
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  IcueTextField(
                    controller: _relation,
                    label: l10n.relation,
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                  const SizedBox(height: 16),
                  IcueTextField(
                    controller: _mobile,
                    label: l10n.mobileNumber,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: IndianPhoneValidator.validate,
                  ),
                  if (_type == escortTemporary) ...[
                    const SizedBox(height: 16),
                    IcueDateField(
                      controller: _from,
                      label: l10n.fromDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      validator: required,
                    ),
                    const SizedBox(height: 16),
                    IcueDateField(
                      controller: _to,
                      label: l10n.toDate,
                      initialDate: _from.text.toDateOrNull(),
                      firstDate: _from.text.toDateOrNull() ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      validator: required,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _PhotoBox(
                    photo: _photo,
                    uploadLabel: l10n.uploadPhoto,
                    onPick: _pickPhoto,
                    onClear: () => setState(() => _photo = null),
                  ),
                  const SizedBox(height: 30),
                  IcueButton(
                    label: l10n.submit,
                    isFullWidth: true,
                    size: IcueButtonSize.large,
                    isLoading: busy,
                    onPressed: busy ? null : _submit,
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

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.photo,
    required this.uploadLabel,
    required this.onPick,
    required this.onClear,
  });

  final IcuePickedFile? photo;
  final String uploadLabel;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => DottedBorder(
    options: const RoundedRectDottedBorderOptions(
      radius: Radius.circular(10),
      dashPattern: [8, 6],
    ),
    child: photo == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: IcueButton(
                label: uploadLabel,
                variant: IcueButtonVariant.outline,
                onPressed: onPick,
              ),
            ),
          )
        : Stack(
            alignment: Alignment.topRight,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Image.memory(
                  Uint8List.fromList(photo!.bytes),
                  height: 200,
                  width: double.infinity,
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          ),
  );
}
