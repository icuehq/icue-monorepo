import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/ui/stock/shared/line_editor.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';

class IssueRequestFormPage extends StatefulWidget {
  const IssueRequestFormPage({super.key});

  @override
  State<IssueRequestFormPage> createState() => _IssueRequestFormPageState();
}

class _IssueRequestFormPageState extends State<IssueRequestFormPage> {
  final _form = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _destination = TextEditingController();
  final _lines = <LineDraft>[];
  final _requestId = newRequestId();
  String? _store;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    ensureMasters(context);
  }

  @override
  void dispose() {
    _purpose.dispose();
    _destination.dispose();
    for (final lineDraft in _lines) {
      lineDraft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_lines.isEmpty) return showMessage(context, 'Add at least one item');
    setState(() => _busy = true);
    await stockSubmit(
      context,
      (stockProvider) => stockProvider.act('inventory-issueRequest-submit', {
        'storeId': _store,
        'purpose': _purpose.text.trim(),
        'destination': _destination.text.trim(),
        'lineItems': [for (final lineDraft in _lines) lineDraft.toMap()],
      }, requestId: _requestId),
      done: 'Request submitted successfully',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Issue Request')),
      body: IcueCenteredBody(
        maxWidth: 900,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Store & Purpose',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StoreDropdown(
                        label: 'Issue from store',
                        value: _store,
                        onChanged: (value) => setState(() => _store = value),
                      ),
                      const SizedBox(height: 12),
                      IcueTextField(
                        controller: _purpose,
                        validator: requiredText,
                        label: 'Purpose',
                        hintText:
                            'e.g. Science lab experiments, Staff training',
                      ),
                      const SizedBox(height: 12),
                      IcueTextField(
                        controller: _destination,
                        label: 'Destination / Department (optional)',
                        hintText: 'e.g. Senior Chemistry Lab, Block B',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Requested Items',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_lines.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_lines.length} items',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LineEditor(
                        lineItems: _lines,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              IcueButton(
                label: _busy ? 'Submitting…' : 'Submit Request',
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.send_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
