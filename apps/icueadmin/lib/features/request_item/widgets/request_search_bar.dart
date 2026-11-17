import 'package:flutter/material.dart';

/// Search input bar with clear action and search icon for the item catalog.
class RequestSearchBar extends StatelessWidget {
  const RequestSearchBar({
    required this.controller,
    required this.onSearchChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search items by name...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();
                  onSearchChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      onChanged: (value) {
        if (value.isEmpty) {
          onSearchChanged('');
        }
      },
    );
  }
}
