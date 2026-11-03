import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/library_form_sheet.dart';

class LibrariesPage extends StatelessWidget {
  const LibrariesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.settings');
    return Scaffold(
      appBar: AppBar(title: const Text('Libraries')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => LibraryFormSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Library'),
            )
          : null,
      body: libraryProvider.libraries.isEmpty
          ? Center(
              child: Text(
                libraryProvider.isLoading ? 'Loading…' : 'No libraries yet',
              ),
            )
          : ListView(
              children: [
                for (final schoolLibrary in libraryProvider.libraries)
                  ListTile(
                    title: Text(schoolLibrary.name),
                    subtitle: Text(
                      '${schoolLibrary.code} · Campus ${schoolLibrary.campusId}'
                      '${schoolLibrary.location == null ? '' : ' · ${schoolLibrary.location}'}'
                      '${schoolLibrary.hours == null ? '' : '\n${schoolLibrary.hours}'}',
                    ),
                    isThreeLine: schoolLibrary.hours != null,
                    leading: schoolLibrary.active
                        ? null
                        : const InactiveBadge(),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await LibraryFormSheet.show(
                                  context,
                                  library: schoolLibrary,
                                );
                              } else if (!await libraryProvider
                                      .setLibraryActive(
                                        schoolLibrary.id,
                                        active: !schoolLibrary.active,
                                      ) &&
                                  context.mounted) {
                                showMessage(
                                  context,
                                  libraryProvider.errorMessage ?? 'Failed',
                                );
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
                                  schoolLibrary.active
                                      ? 'Deactivate'
                                      : 'Activate',
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
