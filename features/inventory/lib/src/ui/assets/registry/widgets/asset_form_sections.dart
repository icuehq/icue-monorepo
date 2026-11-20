import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/registry/widgets/asset_item_field.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
import 'package:inventory/src/ui/stock/shared/stock_ui.dart';

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

/// Section for selecting the item, name, store and quantity.
class AssetSectionCard extends StatelessWidget {
  const AssetSectionCard({
    required this.item,
    required this.onPick,
    required this.nameController,
    required this.store,
    required this.onStoreChanged,
    required this.quantityController,
    required this.units,
    required this.maxQuantity,
    required this.onQuantityChanged,
    super.key,
  });

  final InventoryItem? item;
  final VoidCallback onPick;
  final TextEditingController nameController;
  final String? store;
  final ValueChanged<String?> onStoreChanged;
  final TextEditingController quantityController;
  final int units;
  final int maxQuantity;
  final VoidCallback onQuantityChanged;

  String? _validateQuantity(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 1 || number > maxQuantity) {
      return 'Enter a whole number from 1 to $maxQuantity';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Asset',
    icon: Icons.inventory_2_outlined,
    children: [
      StoreDropdown(
        key: ValueKey('store-$store'),
        value: store,
        label: 'Store *',
        prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
        onChanged: onStoreChanged,
      ),
      AssetItemField(
        key: ValueKey('item-${item?.id}'),
        item: item,
        onPick: onPick,
      ),
      formPair(
        IcueTextField(
          controller: nameController,
          label: 'Asset name',
          icon: Icons.badge_outlined,
          helperText: 'Defaults to the item name',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (value) => _maxLength(value, 100, 'Name'),
        ),
        IcueTextField(
          controller: quantityController,
          label: 'Quantity',
          icon: Icons.format_list_numbered_rounded,
          helperText: units > 1
              ? 'Batch: $units units'
              : 'Up to $maxQuantity units',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validateQuantity,
          onChanged: (_) => onQuantityChanged(),
        ),
      ),
    ],
  );
}

/// Section for make, model, serial number and condition.
class AssetIdentificationCard extends StatelessWidget {
  const AssetIdentificationCard({
    required this.makeController,
    required this.modelController,
    required this.serialController,
    required this.units,
    required this.condition,
    required this.onConditionChanged,
    super.key,
  });

  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController serialController;
  final int units;
  final String condition;
  final ValueChanged<String?> onConditionChanged;

  @override
  Widget build(BuildContext context) => IcueFormSectionCard(
    title: 'Identification',
    icon: Icons.qr_code_2_rounded,
    children: [
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
        helperText: units > 1
            ? 'Not available for a batch: serial numbers are unique per '
                  'unit. Set quantity to 1 to enter one.'
            : null,
        enabled: units <= 1,
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
    required this.units,
    required this.totalPrice,
    required this.onPriceChanged,
    required this.validateWarrantyStart,
    required this.validateWarrantyEnd,
    super.key,
  });

  final TextEditingController purchasedController;
  final TextEditingController priceController;
  final TextEditingController warrantyStartController;
  final TextEditingController warrantyEndController;
  final int units;
  final double? totalPrice;
  final VoidCallback onPriceChanged;
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
            label: units > 1 ? 'Unit price' : 'Purchase price',
            icon: Icons.payments_outlined,
            prefixText: '₹ ',
            helperText: totalPrice != null && units > 1
                ? 'Total: ${totalPrice!.toRupees()} for $units units'
                : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [decimalInputFormatter],
            validator: _validatePrice,
            onChanged: (_) => onPriceChanged(),
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
