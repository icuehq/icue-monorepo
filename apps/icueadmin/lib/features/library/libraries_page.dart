import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/library_form_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class LibrariesPage extends StatelessWidget {
  const LibrariesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final canEdit = p.access.can('lib.settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Libraries')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => LibraryFormSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Library'),
            )
          : null,
      body: p.libraries.isEmpty
          ? Center(child: Text(p.isLoading ? 'Loading…' : 'No libraries yet'))
          : ListView(
              children: [
                for (final l in p.libraries)
                  ListTile(
                    title: Text(l.name),
                    subtitle: Text(
                      '${l.code} · Campus ${l.campusId}'
                      '${l.location == null ? '' : ' · ${l.location}'}'
                      '${l.hours == null ? '' : '\n${l.hours}'}',
                    ),
                    isThreeLine: l.hours != null,
                    leading: l.active ? null : const InactiveBadge(),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await LibraryFormSheet.show(
                                  context,
                                  library: l,
                                );
                              } else if (!await p.setLibraryActive(
                                    l.id,
                                    active: !l.active,
                                  ) &&
                                  context.mounted) {
                                invSnack(context, p.errorMessage ?? 'Failed');
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                  l.active ? 'Deactivate' : 'Activate',
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
