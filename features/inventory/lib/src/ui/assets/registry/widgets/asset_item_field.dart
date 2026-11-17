import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Tappable card that shows the chosen asset item, or asks to pick one; shows [FormField] errors under it.
class AssetItemField extends FormField<InventoryItem> {
  AssetItemField({
    required InventoryItem? item,
    required VoidCallback onPick,
    super.key,
  }) : super(
         initialValue: item,
         validator: (_) => item == null ? 'Choose the asset item' : null,
         builder: (state) {
           final theme = Theme.of(state.context);
           final chosen = item;
           final hasError = state.hasError;
           final borderColor = hasError
               ? theme.colorScheme.error
               : (chosen == null
                     ? theme.colorScheme.outlineVariant
                     : theme.colorScheme.primary.withValues(alpha: 0.4));
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               InkWell(
                 borderRadius: BorderRadius.circular(12),
                 onTap: onPick,
                 child: Container(
                   padding: const EdgeInsets.symmetric(
                     horizontal: 16,
                     vertical: 12,
                   ),
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: borderColor),
                     color: chosen == null
                         ? theme.colorScheme.surface
                         : theme.colorScheme.primaryContainer.withValues(
                             alpha: 0.15,
                           ),
                   ),
                   child: Row(
                     children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: chosen == null
                               ? theme.colorScheme.surfaceContainerHighest
                               : theme.colorScheme.primaryContainer,
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Icon(
                           chosen == null
                               ? Icons.inventory_2_outlined
                               : Icons.check_circle_rounded,
                           size: 20,
                           color: hasError
                               ? theme.colorScheme.error
                               : (chosen == null
                                     ? theme.colorScheme.onSurfaceVariant
                                     : theme.colorScheme.primary),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               chosen?.name ?? 'Choose asset item *',
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                               style: theme.textTheme.titleSmall?.copyWith(
                                 fontWeight: FontWeight.w600,
                               ),
                             ),
                             const SizedBox(height: 2),
                             Text(
                               chosen == null
                                   ? 'Only items tracked as individual assets'
                                   : 'Asset-tracked item${chosen.stockUnit.isNotEmpty ? ' · Unit: ${chosen.stockUnit}' : ''}',
                               style: theme.textTheme.bodySmall?.copyWith(
                                 color: theme.colorScheme.onSurfaceVariant,
                               ),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(width: 8),
                       IcueButton(
                         label: chosen == null ? 'Select' : 'Change',
                         variant: chosen == null
                             ? IcueButtonVariant.outline
                             : IcueButtonVariant.ghost,
                         size: IcueButtonSize.small,
                         onPressed: onPick,
                       ),
                     ],
                   ),
                 ),
               ),
               if (hasError)
                 Padding(
                   padding: const EdgeInsets.only(left: 14, top: 6),
                   child: Text(
                     state.errorText!,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: theme.colorScheme.error,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}
