import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

class SelectPointsResult {
  const SelectPointsResult({
    required this.pointNames,
    required this.studentIds,
  });

  final List<String> pointNames;
  final List<int> studentIds;
}

class SelectPointsDialog extends StatefulWidget {
  const SelectPointsDialog({
    super.key,
    required this.availablePoints,
    required this.initialSelectedNames,
  });

  final List<RoutePoint> availablePoints;
  final List<String> initialSelectedNames;

  @override
  State<SelectPointsDialog> createState() => _SelectPointsDialogState();
}

class _SelectPointsDialogState extends State<SelectPointsDialog> {
  late List<String> _selectedNames;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedNames = List<String>.from(widget.initialSelectedNames);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.availablePoints.where((p) {
      if (_query.isEmpty) return true;
      return p.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final allSelected = widget.availablePoints.isNotEmpty &&
        _selectedNames.length == widget.availablePoints.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Select Points',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedNames.clear();
                } else {
                  _selectedNames =
                      widget.availablePoints.map((p) => p.name).toList();
                }
              });
            },
            child: Text(allSelected ? 'Deselect All' : 'Select All'),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 380,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search points...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching points found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final point = filtered[index];
                        final isChecked = _selectedNames.contains(point.name);

                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            point.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${point.studentIds.length} students',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedNames.add(point.name);
                              } else {
                                _selectedNames.remove(point.name);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final studentIds = <int>{};
            for (final name in _selectedNames) {
              final pt = widget.availablePoints.firstWhere(
                (p) => p.name == name,
                orElse: () => const RoutePoint(name: ''),
              );
              studentIds.addAll(pt.studentIds);
            }
            Navigator.of(context).pop(
              SelectPointsResult(
                pointNames: _selectedNames,
                studentIds: studentIds.toList(),
              ),
            );
          },
          child: Text('Done (${_selectedNames.length})'),
        ),
      ],
    );
  }
}
