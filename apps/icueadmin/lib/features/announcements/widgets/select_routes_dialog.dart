import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

class SelectRoutesDialog extends StatefulWidget {
  const SelectRoutesDialog({
    super.key,
    required this.availableRoutes,
    required this.initialSelectedRouteIds,
  });

  final List<Routee> availableRoutes;
  final List<int> initialSelectedRouteIds;

  @override
  State<SelectRoutesDialog> createState() => _SelectRoutesDialogState();
}

class _SelectRoutesDialogState extends State<SelectRoutesDialog> {
  late List<int> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = List<int>.from(widget.initialSelectedRouteIds);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.availableRoutes.where((r) {
      if (_query.isEmpty) return true;
      return r.routeNo.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final allSelected =
        widget.availableRoutes.isNotEmpty &&
        _selectedIds.length == widget.availableRoutes.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Select Routes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedIds.clear();
                } else {
                  _selectedIds = widget.availableRoutes
                      .map((r) => r.id)
                      .toList();
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
                hintText: 'Search routes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                        'No matching routes found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final route = filtered[index];
                        final isChecked = _selectedIds.contains(route.id);

                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            'Route ${route.routeNo}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${route.points.length} stops',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(route.id);
                              } else {
                                _selectedIds.remove(route.id);
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
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: Text('Done (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
