import 'package:auth/auth.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_card_tile.dart';
import 'package:provider/provider.dart';

class DropBoardingPage extends StatefulWidget {
  const DropBoardingPage({super.key});

  @override
  State<DropBoardingPage> createState() => _DropBoardingPageState();
}

class _DropBoardingPageState extends State<DropBoardingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user != null) {
        context.read<DropBoardingProvider>().fetchInitialData(
          zoneId: user.zoneId,
          branchId: auth.selectedBranch?.id ?? user.branchId,
          organizationId: user.organizationId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drop & Boarding')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OptionCardTile(
            iconAsset: 'assets/dashboard/drop-vehicles.png',
            title: 'Drop-off Vehicles',
            subtitle:
                'Record campus arrival of vehicles arriving from drop routes.',
            onTap: () => context.push(AppRoutes.dropVehicles),
          ),
          OptionCardTile(
            iconAsset: 'assets/dashboard/boarding-status.png',
            title: 'Boarding Status',
            subtitle: 'Track parked vehicles awaiting departure and mark them as left.',
            onTap: () => context.push(AppRoutes.boarding),
          ),
        ],
      ),
    );
  }
}
