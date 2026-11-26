import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icue_webview/icue_webview.dart';
import 'package:parent_l10n/parent_l10n.dart';
import 'package:provider/provider.dart';
import 'package:students/students.dart';

/// Opens a school web page (fees, appointments) whose address the server
/// gives per student for [linkType] (`FEES`, `APPNTS`).
class LinkWebViewPage extends StatefulWidget {
  const LinkWebViewPage({
    required this.linkType,
    required this.title,
    super.key,
  });

  final String linkType;
  final String title;

  @override
  State<LinkWebViewPage> createState() => _LinkWebViewPageState();
}

class _LinkWebViewPageState extends State<LinkWebViewPage> {
  late final Future<String?> _url = context
      .read<ParentStudentsProvider>()
      .linkUrl(widget.linkType);

  @override
  Widget build(BuildContext context) {
    final bar = IcueContextBar(
      label: context.watch<ParentAuthProvider>().selectedStudent?.name,
    );
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url != null) {
          return IcueWebViewPage(url: url, title: widget.title, bottom: bar);
        }
        final loading = snapshot.connectionState != ConnectionState.done;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.primary,
          appBar: AppBar(title: Text(widget.title), bottom: bar),
          body: IcueSheetBody(
            loading: loading,
            hasData: false,
            emptyTitle: ParentLocalizations.of(context).tryAgainMessage,
            child: const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
