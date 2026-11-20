import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gatepass/src/providers/parent_gatepass_provider.dart';
import 'package:gatepass/src/ui/widgets/gatepass_request_card.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

/// The parent's gate pass requests, optionally for a date range of up to 10 days.
class GatePassRequestsPage extends StatefulWidget {
  const GatePassRequestsPage({super.key});

  @override
  State<GatePassRequestsPage> createState() => _GatePassRequestsPageState();
}

class _GatePassRequestsPageState extends State<GatePassRequestsPage> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ParentGatePassProvider>();
      provider.loadTypes(); // for the display names
      provider.loadRequests();
    });
  }

  Future<void> _onPicked(DateTimeRange picked) async {
    setState(() => _range = picked);
    await context.read<ParentGatePassProvider>().loadRequests(
      from: picked.start,
      to: picked.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<ParentGatePassProvider>();
    final range = _range;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.gatePassRequests),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IcueContextBar(
                label: context
                    .watch<ParentAuthProvider>()
                    .selectedStudent
                    ?.name,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: IcueDateRangeChip(
                  range: range,
                  emptyLabel: l10n.selectDateRange,
                  tooLongMessage: l10n.dateRangeLimited,
                  onPicked: _onPicked,
                ),
              ),
            ],
          ),
        ),
      ),
      body: IcueSheetBody(
        loading: provider.loading,
        hasData: provider.requests.isNotEmpty,
        emptyTitle: l10n.noDataFound,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: provider.requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = provider.requests[index];
            final name = provider.types
                .where((t) => t.category == request.gatePassType)
                .map((t) => t.displayName)
                .firstOrNull;
            return GatePassRequestCard(
              request: request,
              typeName: name ?? request.gatePassType,
            );
          },
        ),
      ),
    );
  }
}
