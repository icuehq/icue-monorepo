import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';
import 'package:provider/provider.dart';

/// Adds a unit or edits [unit]: a dialog on wide screens, a full screen on phones.
class UnitDialog extends StatefulWidget {
  const UnitDialog({super.key, this.unit});

  final InventoryUnit? unit;

  static Future<void> show(BuildContext context, {InventoryUnit? unit}) =>
      showFormPage(context, () => UnitDialog(unit: unit));

  @override
  State<UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<UnitDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.unit?.name);
  late String? _storeId = widget.unit?.storeId;
  int _nextSample = 0;
  bool _busy = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Fills the form with the next sample whose name is not taken yet (debug builds, new units only).
  void _fillSample() {
    final taken = {
      for (final unit in context.read<InventoryProvider>().units)
        if (unit.storeId == _storeId) unit.name.trim().toLowerCase(),
    };
    for (var tried = 0; tried < _sampleUnits.length; tried++) {
      final sample = _sampleUnits[_nextSample++ % _sampleUnits.length];
      if (taken.contains(sample.toLowerCase())) continue;
      setState(() => _name.text = sample);
      return;
    }
    setState(() => _errorMessage = 'All sample units already exist');
  }

  /// Required, and unique among units (compared ignoring case).
  String? _validateName(String? value) {
    final required = requiredText(value);
    if (required != null) return required;
    final name = value!.trim().toLowerCase();
    final exists = context.read<InventoryProvider>().units.any(
      (unit) =>
          unit.id != widget.unit?.id &&
          unit.storeId == _storeId &&
          unit.name.trim().toLowerCase() == name,
    );
    return exists ? '"${value.trim()}" already exists' : null;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final unit = widget.unit;
    final provider = context.read<InventoryProvider>();
    final name = _name.text.trim();
    final saved = await submitAndClose<InventoryProvider>(
      context,
      () => provider.saveUnit(storeId: _storeId!, name: name, unit: unit),
    );
    if (mounted && !saved) {
      setState(() {
        _busy = false;
        _errorMessage = provider.errorMessage ?? 'Could not save unit';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.unit != null;

    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.straighten_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? 'Edit Unit' : 'New Unit',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'A unit of measurement for stock quantities.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode && !editing)
                IcueButton(
                  label: 'Fill sample',
                  onPressed: _busy ? null : _fillSample,
                  variant: IcueButtonVariant.ghost,
                  leadingIcon: Icons.auto_fix_high_rounded,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          IcueFormSectionCard(
            title: 'Unit Details',
            icon: Icons.straighten_outlined,
            children: [
              StoreDropdown(
                label: 'Store *',
                value: _storeId,
                enabled: !editing,
                onChanged: (value) => setState(() => _storeId = value),
              ),
              IcueTextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
                onFieldSubmitted: (_) => _save(),
                label: 'Unit name *',
                hintText: 'e.g. Kilogram, Box, Piece',
                icon: Icons.label_outline,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IcueButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                variant: IcueButtonVariant.outline,
              ),
              const SizedBox(width: 12),
              IcueButton(
                label: _busy
                    ? 'Saving…'
                    : (editing ? 'Save changes' : 'Create unit'),
                onPressed: _busy ? null : _save,
                leadingIcon: Icons.check_rounded,
                isLoading: _busy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _sampleUnits = [
  'Kilogram',
  'Litre',
  'Piece',
  'Box',
  'Metre',
  'Packet',
  'Dozen',
  'Roll',
];
