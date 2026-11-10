import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Auto-generates a standardized code from a unit name.
String generateUnitCode(String unitName, List<InventoryUnit> existingUnits) {
  final normalized = unitName.trim().toLowerCase();
  const standardUnitCodes = <String, String>{
    'piece': 'pcs',
    'pieces': 'pcs',
    'box': 'box',
    'boxes': 'box',
    'packet': 'pkt',
    'packets': 'pkt',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'gram': 'g',
    'grams': 'g',
    'litre': 'l',
    'litres': 'l',
    'liter': 'l',
    'liters': 'l',
    'millilitre': 'ml',
    'millilitres': 'ml',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'metre': 'm',
    'metres': 'm',
    'meter': 'm',
    'meters': 'm',
    'centimetre': 'cm',
    'centimetres': 'cm',
    'centimeter': 'cm',
    'centimeters': 'cm',
    'millimetre': 'mm',
    'millimetres': 'mm',
    'millimeter': 'mm',
    'millimeters': 'mm',
    'set': 'set',
    'sets': 'set',
    'pair': 'pair',
    'pairs': 'pair',
    'dozen': 'doz',
    'dozens': 'doz',
    'roll': 'roll',
    'rolls': 'roll',
    'bundle': 'bundle',
    'bundles': 'bundle',
    'bottle': 'bottle',
    'bottles': 'bottle',
    'bag': 'bag',
    'bags': 'bag',
    'can': 'can',
    'cans': 'can',
    'carton': 'carton',
    'cartons': 'carton',
    'pack': 'pack',
    'packs': 'pack',
    'sheet': 'sheet',
    'sheets': 'sheet',
    'drum': 'drum',
    'drums': 'drum',
    'square meter': 'sqm',
    'square meters': 'sqm',
    'square foot': 'sqft',
    'square feet': 'sqft',
  };

  var baseCode = standardUnitCodes[normalized];
  if (baseCode == null) {
    baseCode = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (baseCode.isEmpty) {
      baseCode = 'unit';
    }
  }

  final existingCodes = existingUnits
      .map((existingUnit) => existingUnit.code.trim().toLowerCase())
      .toSet();

  var candidate = baseCode;
  var counter = 2;
  while (existingCodes.contains(candidate.toLowerCase())) {
    candidate = '${baseCode}_$counter';
    counter++;
  }
  return candidate;
}

class UnitDialog extends StatefulWidget {
  const UnitDialog({super.key, this.unit});

  final InventoryUnit? unit;

  static Future<bool?> show(BuildContext context, {InventoryUnit? unit}) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => UnitDialog(unit: unit),
      );

  @override
  State<UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<UnitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.unit?.name);
  bool _isBusy = false;
  bool _hasSubmitted = false;
  String? _errorMessage;

  bool get _isEditing => widget.unit != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _hasSubmitted = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isBusy = true);
    final inventoryProvider = context.read<InventoryProvider>();
    final enteredName = _nameController.text.trim();

    final String unitCode;
    if (_isEditing) {
      unitCode = widget.unit!.code;
    } else {
      unitCode = generateUnitCode(enteredName, inventoryProvider.units);
    }

    final success = await inventoryProvider.saveUnit(unitCode, enteredName);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isBusy = false;
        _errorMessage = inventoryProvider.errorMessage ?? 'Could not save unit';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Form(
            key: _formKey,
            autovalidateMode: _hasSubmitted
                ? AutovalidateMode.onUserInteraction
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.straighten_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit unit' : 'Add unit',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                IcueTextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  validator: requiredText,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  onFieldSubmitted: (_) => _handleSave(),
                  label: 'Unit name *',
                  hintText: 'e.g. Kilogram, Box, Piece',
                  icon: Icons.label_outline,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IcueButton(
                      label: 'Cancel',
                      onPressed: _isBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      variant: IcueButtonVariant.ghost,
                    ),
                    const SizedBox(width: 8),
                    IcueButton(
                      label: _isEditing ? 'Save changes' : 'Add unit',
                      onPressed: _isBusy ? null : _handleSave,
                      isLoading: _isBusy,
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
