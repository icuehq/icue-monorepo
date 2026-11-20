import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:parent_transport/src/providers/transport_attendance_provider.dart';
import 'package:parent_transport/src/ui/widgets/transport_record_card.dart';
import 'package:provider/provider.dart';

/// Bus pickup and drop events of the student, optionally for up to 10 days.
class TransportAttendancePage extends StatefulWidget {
  const TransportAttendancePage({super.key});

  @override
  State<TransportAttendancePage> createState() =>
      _TransportAttendancePageState();
}

class _TransportAttendancePageState extends State<TransportAttendancePage> {
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<TransportAttendanceProvider>().load(),
    );
  }

  Future<void> _onPicked(DateTimeRange picked) async {
    setState(() => _range = picked);
    await context.read<TransportAttendanceProvider>().load(
      from: picked.start,
      to: picked.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<TransportAttendanceProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.transportAttendance),
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
                  range: _range,
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
        hasData: provider.records.isNotEmpty,
        emptyTitle: l10n.noDataFound,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: provider.records.length,
          itemBuilder: (_, index) =>
              TransportRecordCard(record: provider.records[index]),
        ),
      ),
    );
  }
}
