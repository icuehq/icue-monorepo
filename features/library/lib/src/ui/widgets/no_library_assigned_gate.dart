import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/src/providers/library_provider.dart';
import 'package:school_library/src/ui/widgets/librarian_logout_button.dart';

/// Shows [child] unless a librarian has no library assigned, then a "contact your branch admin" page.
class NoLibraryAssignedGate extends StatefulWidget {
  const NoLibraryAssignedGate({required this.child, super.key});

  final Widget child;

  @override
  State<NoLibraryAssignedGate> createState() => _NoLibraryAssignedGateState();
}

class _NoLibraryAssignedGateState extends State<NoLibraryAssignedGate> {
  bool _loaded = false;

  Future<void> _load() async {
    final libraryProvider = context.read<LibraryProvider>();
    await libraryProvider.loadMasters();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isAssignedLibrariesOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<AuthProvider>().isAssignedLibrariesOnly) {
      return widget.child;
    }
    final libraryProvider = context.watch<LibraryProvider>();
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (libraryProvider.errorMessage != null) {
      return Scaffold(
        body: IcueEmptyState.error(
          message: libraryProvider.errorMessage,
          onAction: () {
            setState(() => _loaded = false);
            _load();
          },
        ),
      );
    }
    if (libraryProvider.libraries.isNotEmpty) return widget.child;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: const [LibrarianLogoutButton()],
      ),
      body: const IcueEmptyState(
        icon: Icons.local_library_outlined,
        title: 'No library assigned',
        message:
            'You have not been assigned to any library yet. '
            'Please contact your branch admin to get one assigned.',
        neutral: true,
      ),
    );
  }
}
