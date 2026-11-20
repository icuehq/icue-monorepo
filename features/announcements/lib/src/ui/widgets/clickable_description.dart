import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _linkOrPhone = RegExp(
  r'(https?:\/\/[^\s]+|(?:\+91[-\s]?)?(?:91[-\s]?)?[6-9]\d{4}[-\s]?\d{5})',
  caseSensitive: false,
);

/// Text whose links open in the browser and phone numbers open the dialer.
class ClickableDescription extends StatefulWidget {
  const ClickableDescription({required this.description, super.key});

  final String description;

  @override
  State<ClickableDescription> createState() => _ClickableDescriptionState();
}

class _ClickableDescriptionState extends State<ClickableDescription> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Uri _target(String match) => match.toLowerCase().startsWith('http')
      ? Uri.parse(match)
      : Uri(scheme: 'tel', path: match.replaceAll(RegExp(r'[-\s]'), ''));

  List<TextSpan> _spans(String text) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    const plain = TextStyle(color: Color(0xFF605F5F));
    final spans = <TextSpan>[];
    var last = 0;
    for (final match in _linkOrPhone.allMatches(text)) {
      if (match.start > last) {
        spans.add(
          TextSpan(text: text.substring(last, match.start), style: plain),
        );
      }
      final value = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => launchUrl(_target(value));
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: value,
          recognizer: recognizer,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: plain));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: _spans(widget.description)),
    style: const TextStyle(fontSize: 16),
  );
}
