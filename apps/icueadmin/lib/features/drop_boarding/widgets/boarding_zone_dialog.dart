import 'package:drop_boarding/drop_boarding.dart';
import 'package:flutter/material.dart';

class BoardingZoneDialog extends StatefulWidget {
  const BoardingZoneDialog({required this.boardingTypes, super.key});

  final List<BoardingType> boardingTypes;

  @override
  State<BoardingZoneDialog> createState() => _BoardingZoneDialogState();
}

class _BoardingZoneDialogState extends State<BoardingZoneDialog> {
  String? _selectedZone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select Boarding Zone'),
      content: SizedBox(
        width: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.boardingTypes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = widget.boardingTypes[index];
            final isSelected = item.name == _selectedZone;

            return ListTile(
              title: Text(
                item.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.shade400,
                  width: isSelected ? 2 : 1,
                ),
              ),
              dense: true,
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primary.withValues(
                alpha: 0.08,
              ),
              onTap: () {
                setState(() {
                  _selectedZone = item.name;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedZone == null
              ? null
              : () => Navigator.of(context).pop(_selectedZone),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
