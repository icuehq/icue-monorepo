import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/drivers/widgets/driver_list_item.dart';
import 'package:icueadmin/features/drivers/widgets/driver_search_bar.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class DriversPage extends StatefulWidget {
  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isFabVisibleNotifier = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DriverProvider>().fetchDrivers();
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

  void _onAddDriver() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(AppRoutes.addDriver);
  }

  @override
  Widget build(BuildContext context) {
    final driverProvider = context.watch<DriverProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers'),
      ),
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
                onPressed: _onAddDriver,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Driver'),
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DriverSearchBar(
              controller: _searchController,
              onChanged: (val) => _searchQueryNotifier.value = val.trim().toLowerCase(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<DriverProvider>().fetchDrivers(),
              child: _buildBody(driverProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DriverProvider provider) {
    if (provider.isLoading && provider.drivers.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (provider.errorMessage != null && provider.drivers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.fetchDrivers(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.drivers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No drivers added yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Tap + Add Driver to create one.',
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
              ? provider.drivers
              : provider.drivers.where((d) {
                  final name = d.fullName.toLowerCase();
                  final mobile = '${d.mobile ?? ''}'.toLowerCase();
                  final lic = (d.licenceNumber ?? '').toLowerCase();
                  return name.contains(query) ||
                      mobile.contains(query) ||
                      lic.contains(query);
                }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No drivers match your search.',
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
              final driver = filtered[index];
              return DriverListItem(
                driver: driver,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  context.push(
                    AppRoutes.driverInfo,
                    extra: driver,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
