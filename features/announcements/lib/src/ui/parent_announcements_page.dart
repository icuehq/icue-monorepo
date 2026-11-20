import 'package:announcements/src/providers/parent_announcements_provider.dart';
import 'package:announcements/src/ui/widgets/clickable_description.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';

class ParentAnnouncementsPage extends StatefulWidget {
  const ParentAnnouncementsPage({super.key});

  @override
  State<ParentAnnouncementsPage> createState() =>
      _ParentAnnouncementsPageState();
}

class _ParentAnnouncementsPageState extends State<ParentAnnouncementsPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<ParentAnnouncementsProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParentAnnouncementsProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final l10n = ParentLocalizations.of(context);
    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        title: Text(l10n.announcements),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      body: IcueSheetBody(
        loading: provider.loading,
        hasData: provider.announcements.isNotEmpty,
        emptyTitle: l10n.noDataFound,
        child: ListView.builder(
          itemCount: provider.announcements.length,
          itemBuilder: (context, index) {
            final item = provider.announcements[index];
            return Card(
              elevation: 3,
              margin: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 16,
                      children: [
                        Icon(Icons.campaign_outlined, size: 50, color: primary),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${item.date} ${item.time}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Divider(),
                    ClickableDescription(description: item.description),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
