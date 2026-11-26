import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:school_connect/src/models/complaint.dart';
import 'package:school_connect/src/providers/complaints_provider.dart';

/// `dd-MM-yyyy::HH:mm` as `dd-MM-yyyy 02:30 PM`.
String _stamp(String raw) {
  final parts = raw.split('::');
  return parts.length == 2 ? '${parts[0]} ${parts[1].toDisplayTime()}' : raw;
}

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintsProvider>()
        ..loadTypes()
        ..loadComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<ComplaintsProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final labels = {
      ComplaintStatus.open: (l10n.complaintOpen, Colors.red),
      ComplaintStatus.inProgress: (l10n.complaintInProgress, Colors.orange),
      ComplaintStatus.resolved: (l10n.complaintResolved, Colors.green),
    };
    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        title: Text(l10n.complaints),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        loading: provider.loading,
        hasData: provider.complaints.isNotEmpty,
        emptyTitle: l10n.noDataFound,
        child: ListView.separated(
          itemCount: provider.complaints.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final item = provider.complaints[index];
            final (statusLabel, statusColor) = labels[item.status]!;
            return ExpansionTile(
              expandedAlignment: Alignment.topLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.all(10),
              title: Text(
                item.query,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    provider.describe(item.type),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(_stamp(item.queryTime)),
                    ],
                  ),
                ],
              ),
              children: [
                Text(
                  l10n.responses,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                for (final res in item.responses) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        res.userType == 'admin' ? l10n.admin : res.userType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      Text(_stamp(res.dateString)),
                    ],
                  ),
                  Text(res.text, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
