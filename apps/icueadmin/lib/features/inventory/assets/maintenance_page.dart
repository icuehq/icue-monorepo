import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/assets/asset_ui.dart';
import 'package:icueadmin/features/inventory/assets/maintenance_form_sheet.dart';
import 'package:icueadmin/features/inventory/assets/maintenance_update_sheet.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Maintenance requests (FRS 10.20). Faults are reported from an asset; this lists and moves them on.
class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  String? _status;

  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.categories.isEmpty) await inv.loadMasters();
    if (!mounted) return;
    final p = context.read<AssetsProvider>();
    await p.loadMaintenance(inv.access, status: _status);
    await p.loadItemNames(
      p.maintenance.expand((m) => m.parts.map((x) => x.itemId)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssetsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _status,
              items: [
                const DropdownMenuItem(child: Text('All statuses')),
                for (final s in InvMaintenance.statuses)
                  DropdownMenuItem(value: s, child: Text(statusLabel(s))),
              ],
              onChanged: (v) {
                _status = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: p.maintenance.isEmpty
                ? Center(
                    child: p.isLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No maintenance requests'),
                  )
                : ListView(
                    children: [
                      for (final m in p.maintenance)
                        ListTile(
                          title: Text('${m.number} · ${m.assetName}'),
                          subtitle: Text(
                            '${m.issue}\n${m.assetCode} · ${statusLabel(m.priority)} priority · ${m.reportedDate}',
                          ),
                          isThreeLine: true,
                          trailing: StatusChip(m.status),
                          onTap: () async {
                            await showInvSheet(
                              context,
                              () => MaintenanceSheet(job: m),
                            );
                            if (mounted) await _load();
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One request: details, parts, and the moves allowed from its status.
class MaintenanceSheet extends StatelessWidget {
  const MaintenanceSheet({required this.job, super.key});

  final InvMaintenance job;

  Future<void> _go(BuildContext context, Widget Function() form) async {
    final nav = Navigator.of(context);
    await showInvSheet(context, form);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = job;
    final p = context.read<AssetsProvider>();
    final manage = context.read<InventoryProvider>().access.can(
      'inv.assets.manage',
    );
    Widget row(String k, String? v) =>
        v == null || v.isEmpty ? const SizedBox.shrink() : Text('$k: $v');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(m.number, style: Theme.of(context).textTheme.titleLarge),
        Row(
          children: [
            Expanded(child: Text('${m.assetName} · ${m.assetCode}')),
            StatusChip(m.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(m.issue),
        row('Priority', statusLabel(m.priority)),
        row('Reported', m.reportedDate),
        row('Technician', m.technician),
        row('Repair details', m.repairDetails),
        row('Repair cost', m.cost?.toStringAsFixed(2)),
        row('Completed', m.completedDate),
        row('Next service', m.nextServiceDate),
        if (m.parts.isNotEmpty)
          row(
            'Parts',
            m.parts.map((x) => '${p.itemName(x.itemId)} × ${x.qty}').join(', '),
          ),
        if (manage && m.isLive) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _go(context, () => MaintenanceFormSheet(job: m)),
                child: const Text('Edit'),
              ),
              for (final s in const [
                'assigned',
                'in_progress',
                'waiting_for_parts',
                'completed',
                'cancelled',
              ])
                if (s != m.status)
                  OutlinedButton(
                    onPressed: () => _go(
                      context,
                      () => MaintenanceUpdateSheet(job: m, status: s),
                    ),
                    child: Text(statusLabel(s)),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
