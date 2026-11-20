import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:icue_ui/icue_ui.dart';

/// URL schemes a page may navigate to; anything else (intent://, upi://...) is blocked.
const _allowedSchemes = {
  'http',
  'https',
  'file',
  'chrome',
  'data',
  'javascript',
  'about',
};

/// Full-screen web view under a coloured app bar. Grants camera/microphone
/// requests from the page and blocks non-web URL schemes.
class IcueWebViewPage extends StatelessWidget {
  const IcueWebViewPage({
    required this.url,
    required this.title,
    this.bottom,
    super.key,
  });

  final String url;
  final String title;

  /// Shown under the title, e.g. an `IcueContextBar`.
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.primary,
    appBar: AppBar(title: Text(title), bottom: bottom),
    body: IcueSheetBody(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          initialSettings: InAppWebViewSettings(
            shouldPrintBackgrounds: true,
            underPageBackgroundColor: Colors.white,
          ),
          onPermissionRequest: (controller, request) async =>
              PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              ),
          shouldOverrideUrlLoading: (controller, action) async {
            final scheme = action.request.url?.scheme;
            return _allowedSchemes.contains(scheme)
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
        ),
      ),
    ),
  );
}
