import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:school_connect/src/providers/events_provider.dart';

/// QR code the parent shows at the school gate.
class RequestForEntryPage extends StatefulWidget {
  const RequestForEntryPage({super.key});

  @override
  State<RequestForEntryPage> createState() => _RequestForEntryPageState();
}

class _RequestForEntryPageState extends State<RequestForEntryPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<EventsProvider>().loadQrCode(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<EventsProvider>();
    final code = provider.qrCode;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.requestForEntry),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        loading: provider.loading,
        hasData: code != null,
        emptyTitle: l10n.noDataFound,
        child: Center(
          child: QrImageView(
            data: code ?? '',
            size: 500,
            padding: const EdgeInsets.all(20),
          ),
        ),
      ),
    );
  }
}
