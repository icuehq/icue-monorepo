import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class TrackingWebviewPage extends StatefulWidget {
  const TrackingWebviewPage({
    required this.url,
    required this.title,
    super.key,
  });

  final String url;
  final String title;

  @override
  State<TrackingWebviewPage> createState() => _TrackingWebviewPageState();
}

class _TrackingWebviewPageState extends State<TrackingWebviewPage> {
  final GlobalKey _webViewKey = GlobalKey();
  InAppWebViewController? _webViewController;
  double _progress = 0;

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllowFullscreen: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            key: _webViewKey,
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: _settings,
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
          ),
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
