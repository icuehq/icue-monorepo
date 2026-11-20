import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show MaintenanceStatus;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/assets/maintenance/widgets/maintenance_dialog.dart';
import 'package:inventory/src/ui/assets/maintenance/widgets/maintenance_update_dialog.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_page.dart';
import 'package:inventory/src/ui/shared/widgets/paged_list_table.dart';
import 'package:provider/provider.dart';

/// Maintenance requests (FRS 10.20). Faults are reported from an asset; this lists and moves them on.
class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  static final _statuses = {
    for (final status in MaintenanceStatus.values)
      status: humanizeStatus(status),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    if (mounted) await context.read<AssetsProvider>().maintenanceList.load();
  }

  Future<void> _open(InventoryMaintenance job) async {
    await showFormPage(context, () => MaintenanceSheet(job: job));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final assetsProvider = context.watch<AssetsProvider>();
    return PagedListPage<InventoryMaintenance>(
      title: 'Maintenance',
      state: assetsProvider.maintenanceList,
      statuses: _statuses,
      searchHint: 'Search by request number…',
      emptyIcon: Icons.build_circle_outlined,
      emptyMessage: 'Faults reported from an asset appear here.',
      onRefresh: _load,
      itemCard: (context, job) => ListTile(
        title: Text('${job.number} · ${job.assetName}'),
        subtitle: Text(
          '${job.issue}\n${job.assetName} · ${humanizeStatus(job.priority)} priority · ${job.reportedDate.toDisplayDay()}',
        ),
        isThreeLine: true,
        trailing: InventoryStatusChip(job.status),
        onTap: () => _open(job),
      ),
      table: PagedListTable<InventoryMaintenance>(
        title: 'Maintenance',
        state: assetsProvider.maintenanceList,
        statuses: _statuses,
        searchHint: 'Request number, e.g. MNT/2025-26',
        rowKey: (job) => job.id,
        rowLabel: (job) => job.number,
        onOpen: _open,
        emptyMessage: 'Faults reported from an asset appear here.',
        columns: [
          IcueTableColumn(
            id: 'number',
            label: 'Request',
            cellBuilder: (context, job) => IcueTableCellText(job.number),
          ),
          IcueTableColumn(
            id: 'asset',
            label: 'Asset',
            flex: 2,
            cellBuilder: (context, job) => IcueTableCellText(job.assetName),
          ),
          IcueTableColumn(
            id: 'issue',
            label: 'Issue',
            flex: 3,
            cellBuilder: (context, job) => IcueTableCellText(job.issue),
          ),
          IcueTableColumn(
            id: 'priority',
            label: 'Priority',
            hideBelowWidth: 900,
            cellBuilder: (context, job) =>
                IcueTableCellText(humanizeStatus(job.priority)),
          ),
          IcueTableColumn(
            id: 'reported',
            label: 'Reported',
            hideBelowWidth: 900,
            cellBuilder: (context, job) =>
                IcueTableCellText(job.reportedDate.toDisplayDay()),
          ),
          IcueTableColumn(
            id: 'status',
            label: 'Status',
            cellBuilder: (context, job) => InventoryStatusChip(job.status),
          ),
        ],
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
            Expanded(child: Text(maintenance.assetName)),
            InventoryStatusChip(maintenance.status),
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
        if (maintenance.isLive) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              IcueButton(
                label: 'Edit',
                onPressed: () =>
                    _go(context, () => MaintenanceDialog(job: maintenance)),
                variant: IcueButtonVariant.outline,
              ),
              for (final value in const [
                'assigned',
                'in_progress',
                'waiting_for_parts',
                'completed',
                'cancelled',
              ])
                if (value != maintenance.status)
                  IcueButton(
                    label: humanizeStatus(value),
                    onPressed: () => _go(
                      context,
                      () => MaintenanceUpdateDialog(
                        job: maintenance,
                        status: value,
                      ),
                    ),
                    variant: IcueButtonVariant.outline,
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
