import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';

final _pricePattern = RegExp(r'^\d{1,9}(\.\d{1,2})?$');

String? _maxLength(String? value, int max, String what) =>
    (value ?? '').trim().length > max
    ? '$what must be $max characters or fewer'
    : null;

String? _validatePrice(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (!_pricePattern.hasMatch(text)) {
    return 'Enter an amount with up to 2 decimals';
  }
  return null;
}

/// Two fields side by side when there is room, stacked on narrow widths.
Widget formPair(Widget first, Widget second) => LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 480) {
      return Column(children: [first, const SizedBox(height: 14), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  },
);

/// The received unit being registered: read-only facts from Receive Stock.
class AssetReceivedCard extends StatelessWidget {
  const AssetReceivedCard({
    required this.asset,
    required this.itemName,
    required this.storeName,
    super.key,
  });

  final InventoryAsset asset;
  final String itemName;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return IcueFormSectionCard(
      title: 'Received unit',
      icon: Icons.inventory_2_outlined,
      children: [
        row('Item', itemName),
        row('Store', storeName),
        row('Asset ID', asset.id),
        if (asset.receivedDate != null)
          row('Received', asset.receivedDate!.toDisplayDay()),
      ],
    );
  }
}

/// Section for make, model, serial number and condition.
class AssetIdentificationCard extends StatelessWidget {
  const AssetIdentificationCard({
    required this.nameController,
    required this.makeController,
    required this.modelController,
    required this.serialController,
    required this.condition,
    required this.onConditionChanged,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController serialController;
  final String condition;
  final ValueChanged<String?> onConditionChanged;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Identification',
    icon: Icons.qr_code_2_rounded,
    children: [
      IcueTextField(
        controller: nameController,
        label: 'Asset name',
        icon: Icons.badge_outlined,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'Enter a name'
            : _maxLength(value, 100, 'Name'),
      ),
      formPair(
        IcueTextField(
          controller: makeController,
          label: 'Manufacturer',
          icon: Icons.domain_outlined,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (value) => _maxLength(value, 60, 'Manufacturer'),
        ),
        IcueTextField(
          controller: modelController,
          label: 'Model',
          icon: Icons.devices_outlined,
          textInputAction: TextInputAction.next,
          validator: (value) => _maxLength(value, 60, 'Model'),
        ),
      ),
      IcueTextField(
        controller: serialController,
        label: 'Serial number',
        icon: Icons.tag_rounded,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next,
        validator: (value) => _maxLength(value, 60, 'Serial'),
      ),
      labelled(
        'Condition',
        AssetCondition.values,
        condition,
        onConditionChanged,
        icon: Icons.verified_outlined,
      ),
    ],
  );
}

/// Section for purchase date, purchase price and warranty.
class AssetPurchaseCard extends StatelessWidget {
  const AssetPurchaseCard({
    required this.purchasedController,
    required this.priceController,
    required this.warrantyStartController,
    required this.warrantyEndController,
    required this.validateWarrantyStart,
    required this.validateWarrantyEnd,
    super.key,
  });

  final TextEditingController purchasedController;
  final TextEditingController priceController;
  final TextEditingController warrantyStartController;
  final TextEditingController warrantyEndController;
  final FormFieldValidator<String>? validateWarrantyStart;
  final FormFieldValidator<String>? validateWarrantyEnd;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 3650));
    final future = now.add(const Duration(days: 3650));

    return IcueFormSectionCard(
      title: 'Purchase and warranty',
      icon: Icons.receipt_long_outlined,
      children: [
        formPair(
          optionalDate(
            context,
            purchasedController,
            'Purchase date',
            first: past,
            last: now,
          ),
          IcueTextField(
            controller: priceController,
            label: 'Purchase price',
            icon: Icons.payments_outlined,
            prefixText: '₹ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [decimalInputFormatter],
            validator: _validatePrice,
          ),
        ),
        formPair(
          IcueDateField(
            controller: warrantyStartController,
            label: 'Warranty start',
            firstDate: past,
            lastDate: future,
            clearable: true,
            validator: validateWarrantyStart,
          ),
          IcueDateField(
            controller: warrantyEndController,
            label: 'Warranty end',
            firstDate: past,
            lastDate: future,
            clearable: true,
            validator: validateWarrantyEnd,
          ),
        ),
      ],
    );
  }
}
