import 'package:flutter/material.dart';

class CacheImage extends StatelessWidget {
  const CacheImage({required this.url, required this.size, super.key});

  final double size;
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || !url.startsWith('http')) {
      return Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(Icons.apps, size: size),
      );
    }

    return Image.network(
      url,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(Icons.apps, size: size),
      ),
    );
  }
}
