import 'package:flutter/material.dart';

/// Loads a deferred library (`import '...' deferred as x;` → `x.loadLibrary`)
/// on first build, then shows [builder]. Keeps the web bundle small by
/// downloading a module's screens only when someone opens one.
class IcueDeferred extends StatefulWidget {
  const IcueDeferred({required this.load, required this.builder, super.key});

  final Future<void> Function() load;
  final WidgetBuilder builder;

  @override
  State<IcueDeferred> createState() => _IcueDeferredState();
}

class _IcueDeferredState extends State<IcueDeferred> {
  late Future<void> _loading = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        return Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load this page.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _loading = widget.load()),
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
