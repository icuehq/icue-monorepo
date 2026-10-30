import 'package:flutter/material.dart';
import 'package:icueadmin/features/routes/widgets/route_time_item.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

class RouteTimeChangePage extends StatefulWidget {
  const RouteTimeChangePage({super.key});

  @override
  State<RouteTimeChangePage> createState() => _RouteTimeChangePageState();
}

class _RouteTimeChangePageState extends State<RouteTimeChangePage> {
  RouteMode _selectedMode = RouteMode.pickup;
  final Set<int> _selectedRouteIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RoutesProvider>().fetchRoutes(_selectedMode);
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onModeChanged(RouteMode mode) {
    if (_selectedMode == mode) return;
    setState(() {
      _selectedMode = mode;
      _selectedRouteIds.clear();
      _searchController.clear();
    });
    context.read<RoutesProvider>().fetchRoutes(mode);
  }

  Future<void> _onPickTimeAndSubmit(List<Routee> routes) async {
    if (_selectedRouteIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one route')),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null || !mounted) return;

    final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
    final minute = picked.minute.toString().padLeft(2, '0');
    final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
    final formattedTime = '$hour:$minute $period';

    final isAllSelected = _selectedRouteIds.length == routes.length;
    final request = UpdateRouteTimeRequest(
      time: formattedTime,
      mode: _selectedMode,
      changeMode: isAllSelected ? 'ALL' : 'CUSTOM',
      selectedRouteIds: _selectedRouteIds.toList(),
    );

    final provider = context.read<RoutesProvider>();
    final success = await provider.updateRouteTime(request);

    if (!mounted) return;

    if (success) {
      setState(() => _selectedRouteIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Route start time updated to $formattedTime'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update time'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutesProvider>();
    final filteredRoutes = _searchQuery.isEmpty
        ? provider.routes
        : provider.routes.where((r) {
            return r.routeNo.toLowerCase().contains(_searchQuery) ||
                (r.vehicleNumber ?? '').toLowerCase().contains(_searchQuery);
          }).toList();

    final isAllSelected = filteredRoutes.isNotEmpty &&
        _selectedRouteIds.length == filteredRoutes.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Time Change'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: provider.isLoading || _selectedRouteIds.isEmpty
                ? null
                : () => _onPickTimeAndSubmit(filteredRoutes),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.schedule_rounded),
            label: Text(
              _selectedRouteIds.isEmpty
                  ? 'Select routes to update time'
                  : 'Update Time for ${_selectedRouteIds.length} routes',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<RouteMode>(
                    segments: const [
                      ButtonSegment(
                        value: RouteMode.pickup,
                        label: Text('Pickup Routes'),
                        icon: Icon(Icons.north_east_rounded),
                      ),
                      ButtonSegment(
                        value: RouteMode.drop,
                        label: Text('Drop Routes'),
                        icon: Icon(Icons.south_west_rounded),
                      ),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (set) => _onModeChanged(set.first),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by route or vehicle number...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (filteredRoutes.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val ?? false) {
                          _selectedRouteIds
                              .addAll(filteredRoutes.map((r) => r.id));
                        } else {
                          _selectedRouteIds.clear();
                        }
                      });
                    },
                  ),
                  Text(
                    'Select All (${filteredRoutes.length} routes)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedRouteIds.length} selected',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildRouteList(provider, filteredRoutes),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteList(RoutesProvider provider, List<Routee> routes) {
    if (provider.isLoading && routes.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (routes.isEmpty) {
      return const Center(
        child: Text(
          'No routes found for the selected mode.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        final isSelected = _selectedRouteIds.contains(route.id);
        return RouteTimeItem(
          route: route,
          isSelected: isSelected,
          onChanged: (val) {
            setState(() {
              if (val) {
                _selectedRouteIds.add(route.id);
              } else {
                _selectedRouteIds.remove(route.id);
              }
            });
          },
        );
      },
    );
  }
}
