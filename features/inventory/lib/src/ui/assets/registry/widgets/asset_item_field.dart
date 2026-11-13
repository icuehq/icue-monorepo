import 'package:flutter/material.dart';
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
           final color = hasError
               ? theme.colorScheme.error
               : theme.colorScheme.outlineVariant;
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               InkWell(
                 borderRadius: BorderRadius.circular(12),
                 onTap: onPick,
                 child: Container(
                   padding: const EdgeInsets.all(14),
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: color),
                     color: chosen == null
                         ? null
                         : theme.colorScheme.primaryContainer.withValues(
                             alpha: 0.25,
                           ),
                   ),
                   child: Row(
                     children: [
                       Icon(
                         chosen == null
                             ? Icons.inventory_2_outlined
                             : Icons.check_circle_rounded,
                         color: hasError
                             ? theme.colorScheme.error
                             : theme.colorScheme.primary,
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
                             if (chosen == null)
                               Text(
                                 'Only items tracked as individual assets',
                                 style: theme.textTheme.bodySmall,
                               ),
                           ],
                         ),
                       ),
                       TextButton(
                         onPressed: onPick,
                         child: Text(chosen == null ? 'Select' : 'Change'),
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
