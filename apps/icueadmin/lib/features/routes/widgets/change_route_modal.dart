import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class ChangeRouteModal extends StatefulWidget {
  const ChangeRouteModal({super.key, required this.student});

  final StudentData student;

  static Future<void> show(BuildContext context, StudentData student) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChangeRouteModal(student: student),
    );
  }

  @override
  State<ChangeRouteModal> createState() => _ChangeRouteModalState();
}

class _ChangeRouteModalState extends State<ChangeRouteModal> {
  String _selectedScope = 'pickup'; // 'pickup', 'drop', 'both'

  int? _selectedPickupRouteId;
  String? _selectedPickupPoint;
  int? _selectedDropRouteId;
  String? _selectedDropPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RoutesProvider>().fetchRoutes(null);
      }
    });
  }

  Future<void> _submitChange() async {
    final provider = context.read<RoutesProvider>();
    final student = widget.student;

    bool success = false;
    if (_selectedScope == 'both') {
      if (_selectedPickupRouteId == null ||
          _selectedPickupPoint == null ||
          _selectedDropRouteId == null ||
          _selectedDropPoint == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both routes and stops')),
        );
        return;
      }

      success = await provider.changeBothRoutes(
        ChangeBothRoutesRequest(
          studentId: student.id,
          classId: student.classId,
          sections: [student.section],
          pickupRoute: _selectedPickupRouteId!,
          pickupPoint: _selectedPickupPoint!,
          dropRoute: _selectedDropRouteId!,
          dropPoint: _selectedDropPoint!,
        ),
      );
    } else {
      final isPickup = _selectedScope == 'pickup';
      final routeId = isPickup ? _selectedPickupRouteId : _selectedDropRouteId;
      final point = isPickup ? _selectedPickupPoint : _selectedDropPoint;

      if (routeId == null || point == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select route and stop')),
        );
        return;
      }

      success = await provider.changeRoute(
        ChangeRouteRequest(
          mode: isPickup ? RouteMode.pickup : RouteMode.drop,
          studentId: student.id,
          classId: student.classId,
          sections: [student.section],
          route: routeId,
          point: point,
        ),
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student route updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update route'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutesProvider>();
    final routes = provider.routes;

    final pickupRoutes = routes
        .where((r) => r.mode == RouteMode.pickup)
        .toList();
    final dropRoutes = routes.where((r) => r.mode == RouteMode.drop).toList();

    final selectedPickupRoute = _selectedPickupRouteId != null
        ? pickupRoutes.firstWhere(
            (r) => r.id == _selectedPickupRouteId,
            orElse: () => pickupRoutes.first,
          )
        : null;

    final selectedDropRoute = _selectedDropRouteId != null
        ? dropRoutes.firstWhere(
            (r) => r.id == _selectedDropRouteId,
            orElse: () => dropRoutes.first,
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Route: ${widget.student.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.student.standard} - ${widget.student.section}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _buildScopeChip('pickup', 'Change Pickup'),
              const SizedBox(width: 8),
              _buildScopeChip('drop', 'Change Drop'),
              const SizedBox(width: 8),
              _buildScopeChip('both', 'Both'),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedScope == 'pickup' || _selectedScope == 'both') ...[
            const Text(
              'Pickup Route & Stop',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedPickupRouteId,
              hint: const Text('Select Pickup Route'),
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: pickupRoutes.map((r) {
                return DropdownMenuItem(
                  value: r.id,
                  child: Text('Route ${r.routeNo} (${r.points.length} stops)'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedPickupRouteId = val;
                  _selectedPickupPoint = null;
                });
              },
            ),
            if (selectedPickupRoute != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedPickupPoint,
                hint: const Text('Select Pickup Stop'),
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: selectedPickupRoute.points.map((p) {
                  return DropdownMenuItem(value: p.name, child: Text(p.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedPickupPoint = val),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (_selectedScope == 'drop' || _selectedScope == 'both') ...[
            const Text(
              'Drop Route & Stop',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedDropRouteId,
              hint: const Text('Select Drop Route'),
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: dropRoutes.map((r) {
                return DropdownMenuItem(
                  value: r.id,
                  child: Text('Route ${r.routeNo} (${r.points.length} stops)'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedDropRouteId = val;
                  _selectedDropPoint = null;
                });
              },
            ),
            if (selectedDropRoute != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedDropPoint,
                hint: const Text('Select Drop Stop'),
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: selectedDropRoute.points.map((p) {
                  return DropdownMenuItem(value: p.name, child: Text(p.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedDropPoint = val),
              ),
            ],
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: provider.isLoading ? null : _submitChange,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: provider.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update Route Assignment'),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String scope, String label) {
    final isSelected = _selectedScope == scope;
    return Expanded(
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedColor: Theme.of(context).primaryColor,
        onSelected: (_) => setState(() => _selectedScope = scope),
      ),
    );
  }
}
