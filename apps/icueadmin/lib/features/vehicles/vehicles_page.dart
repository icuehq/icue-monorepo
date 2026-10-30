import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/vehicles/widgets/vehicle_card.dart';
import 'package:icueadmin/features/vehicles/widgets/vehicle_search_bar.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isFabVisibleNotifier = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VehicleProvider>().fetchVehiclesData();
      }
    });

    _searchController.addListener(() {
      _searchQueryNotifier.value = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    _isFabVisibleNotifier.dispose();
    super.dispose();
  }

  void _onAddVehicle() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(AppRoutes.addVehicle);
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles Fleet')),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _isFabVisibleNotifier,
        builder: (context, isVisible, child) {
          return AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            offset: isVisible ? Offset.zero : const Offset(0, 2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isVisible ? 1.0 : 0.0,
              child: FloatingActionButton.extended(
                onPressed: _onAddVehicle,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Vehicle'),
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: VehicleSearchBar(
              controller: _searchController,
              onChanged: (val) =>
                  _searchQueryNotifier.value = val.trim().toLowerCase(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  context.read<VehicleProvider>().fetchVehiclesData(),
              child: _buildBody(vehicleProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(VehicleProvider provider) {
    if (provider.isLoading && provider.vehiclesData.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (provider.errorMessage != null && provider.vehiclesData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.fetchVehiclesData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.vehiclesData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No vehicles registered in this branch.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Tap + Add Vehicle to register a vehicle.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.reverse) {
          _isFabVisibleNotifier.value = false;
        } else if (notification.direction == ScrollDirection.forward) {
          _isFabVisibleNotifier.value = true;
        }
        return true;
      },
      child: ValueListenableBuilder<String>(
        valueListenable: _searchQueryNotifier,
        builder: (context, query, _) {
          final filtered = query.isEmpty
              ? provider.vehiclesData
              : provider.vehiclesData.where((v) {
                  final num = v.number.toLowerCase();
                  final make = (v.make ?? '').toLowerCase();
                  final model = (v.model ?? '').toLowerCase();
                  final driver = (v.driverName ?? '').toLowerCase();
                  return num.contains(query) ||
                      make.contains(query) ||
                      model.contains(query) ||
                      driver.contains(query);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No vehicles match your search query.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filtered.length,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemBuilder: (context, index) {
              final vehicle = filtered[index];
              return VehicleCard(
                vehicle: vehicle,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.push(AppRoutes.vehicleDetails, extra: vehicle);
                },
              );
            },
          );
        },
      ),
    );
  }
}
