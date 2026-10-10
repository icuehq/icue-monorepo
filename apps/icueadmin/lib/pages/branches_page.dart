import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';
import '../services/injectable.dart';

class BranchesPage extends StatefulWidget {
  const BranchesPage({super.key});

  @override
  State<BranchesPage> createState() => _BranchesPageState();
}

class _BranchesPageState extends State<BranchesPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).getBranchesByZoneId();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Branch')),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) {
                final item = provider.branches[index];
                return ListTile(
                  title: Text(
                    item.schoolName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_sharp),
                  onTap: () async {
                    await HiveService.zonalBranch.put('selected', item);
                    getIt<ApiClient>().invalidateSessionCache();
                    await provider.getRoleActions(context);
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              itemCount: provider.branches.length,
            ),
    );
  }
}
