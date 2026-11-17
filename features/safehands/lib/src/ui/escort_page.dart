import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:safehands/src/models/escort.dart';
import 'package:safehands/src/providers/escort_provider.dart';
import 'package:safehands/src/ui/routing/safehands_router.dart';
import 'package:safehands/src/ui/widgets/escort_photo_dialog.dart';

/// People allowed to pick the student up.
class EscortPage extends StatefulWidget {
  const EscortPage({super.key});

  @override
  State<EscortPage> createState() => _EscortPageState();
}

class _EscortPageState extends State<EscortPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => context.read<EscortProvider>().load(),
    );
  }

  Future<void> _delete(Escort escort) async {
    final l10n = ParentLocalizations.of(context);
    final provider = context.read<EscortProvider>();
    final confirmed = await IcueDialog.confirm(
      context,
      title: l10n.delete,
      message: l10n.areYouSureYouWantToDelete,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed) await provider.remove(escort.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ParentLocalizations.of(context);
    final provider = context.watch<EscortProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        title: Text(l10n.escort),
        bottom: IcueContextBar(
          label: context.watch<ParentAuthProvider>().selectedStudent?.name,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(SafeHandsRoutes.addEscortPath),
        icon: const Icon(Icons.add),
        label: Text(
          l10n.addEscort,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: IcueSheetBody(
        loading: provider.loading,
        hasData: provider.escorts.isNotEmpty,
        emptyTitle: l10n.noDataFound,
        child: ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: provider.escorts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = provider.escorts[index];
            return Card(
              elevation: 2,
              child: ListTile(
                leading: InkWell(
                  onTap: () => showEscortPhoto(context, item.photoUrl),
                  child: CircleAvatar(
                    foregroundImage: NetworkImage(item.photoUrl),
                    backgroundImage: NetworkImage(item.photoUrl),
                  ),
                ),
                title: Text(
                  '${item.name} - ${item.type}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.relation,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (item.isTemporary)
                      Text(
                        l10n.dateRangeFromTo(
                          item.fromDate ?? '',
                          item.toDate ?? '',
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  onPressed: () => _delete(item),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
