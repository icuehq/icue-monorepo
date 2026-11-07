import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show MaintenanceStatus;
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/maintenance/widgets/maintenance_dialog.dart';
import 'package:inventory/src/ui/assets/maintenance/widgets/maintenance_update_dialog.dart';
import 'package:inventory/src/ui/assets/shared/asset_ui.dart';
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
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (!mounted) return;
    final assetsProvider = context.read<AssetsProvider>();
    await assetsProvider.loadMaintenance(
      inventoryProvider.access,
      status: _status,
    );
    await assetsProvider.loadItemNames(
      assetsProvider.maintenance.expand(
        (maintenance) => maintenance.parts.map((partUsed) => partUsed.itemId),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _open(InventoryMaintenance job) async {
    await showFormPage(context, () => MaintenanceSheet(job: job));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      body: CenteredBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _status,
                items: [
                  const DropdownMenuItem(child: Text('All statuses')),
                  for (final status in MaintenanceStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(humanizeStatus(status)),
                    ),
                ],
                onChanged: (value) {
                  _status = value;
                  _load();
                },
              ),
            ),
            Expanded(
              child: assetsProvider.maintenance.isEmpty
                  ? Center(
                      child: assetsProvider.isLoading
                          ? const CircularProgressIndicator()
                          : Text(
                              assetsProvider.errorMessage ??
                                  'No maintenance requests',
                            ),
                    )
                  : AdaptiveList<InventoryMaintenance>(
                      items: assetsProvider.maintenance,
                      onTap: _open,
                      columns: [
                        AdaptiveColumn.text('Request', (job) => job.number),
                        AdaptiveColumn.text(
                          'Asset',
                          (job) => job.assetName,
                          flex: 2,
                        ),
                        AdaptiveColumn.text(
                          'Issue',
                          (job) => job.issue,
                          flex: 3,
                        ),
                        AdaptiveColumn.text(
                          'Priority',
                          (job) => humanizeStatus(job.priority),
                        ),
                        AdaptiveColumn.text(
                          'Reported',
                          (job) => job.reportedDate.toDisplayDay(),
                        ),
                        AdaptiveColumn(
                          label: 'Status',
                          cell: (context, job) => StatusChip(job.status),
                        ),
                      ],
                      cardBuilder: (context, maintenance) => ListTile(
                        title: Text(
                          '${maintenance.number} · ${maintenance.assetName}',
                        ),
                        subtitle: Text(
                          '${maintenance.issue}\n${maintenance.assetCode} · ${humanizeStatus(maintenance.priority)} priority · ${maintenance.reportedDate.toDisplayDay()}',
                        ),
                        isThreeLine: true,
                        trailing: StatusChip(maintenance.status),
                        onTap: () => _open(maintenance),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One request: details, parts, and the moves allowed from its status.
class MaintenanceSheet extends StatelessWidget {
  const MaintenanceSheet({required this.job, super.key});

  final InventoryMaintenance job;

  Future<void> _go(BuildContext context, Widget Function() form) async {
    final navigator = Navigator.of(context);
    await showFormPage(context, form);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = job;
    final assetsProvider = context.read<AssetsProvider>();
    final manage = context.read<InventoryProvider>().access.can(
      'inventory.assets.manage',
    );
    Widget row(String currentValue, String? value) =>
        value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Text('$currentValue: $value');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(maintenance.number, style: Theme.of(context).textTheme.titleLarge),
        Row(
          children: [
            Expanded(
              child: Text(
                '${maintenance.assetName} · ${maintenance.assetCode}',
              ),
            ),
            StatusChip(maintenance.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(maintenance.issue),
        row('Priority', humanizeStatus(maintenance.priority)),
        row('Reported', maintenance.reportedDate.toDisplayDay()),
        row('Technician', maintenance.technician),
        row('Repair details', maintenance.repairDetails),
        row('Repair cost', maintenance.cost?.toRupees()),
        row('Completed', maintenance.completedDate?.toDisplayDay()),
        row('Next service', maintenance.nextServiceDate?.toDisplayDay()),
        if (maintenance.parts.isNotEmpty)
          row(
            'Parts',
            maintenance.parts
                .map(
                  (partUsed) =>
                      '${assetsProvider.itemName(partUsed.itemId)} × ${partUsed.quantity}',
                )
                .join(', '),
          ),
        if (manage && maintenance.isLive) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () =>
                    _go(context, () => MaintenanceDialog(job: maintenance)),
                child: const Text('Edit'),
              ),
              for (final value in const [
                'assigned',
                'in_progress',
                'waiting_for_parts',
                'completed',
                'cancelled',
              ])
                if (value != maintenance.status)
                  OutlinedButton(
                    onPressed: () => _go(
                      context,
                      () => MaintenanceUpdateDialog(
                        job: maintenance,
                        status: value,
                      ),
                    ),
                    child: Text(humanizeStatus(value)),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
