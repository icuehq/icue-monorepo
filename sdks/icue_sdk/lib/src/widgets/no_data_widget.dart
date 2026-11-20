import 'package:flutter/material.dart';

/// Simple placeholder shown when there is no content to display.
class NoDataWidget extends StatelessWidget {
  const NoDataWidget({super.key, this.msg, this.image, this.size});

  final String? image;
  final String? msg;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              image ?? 'assets/tracking.webp',
              width: size ?? 400,
              package: 'icue_sdk',
            ),
            const SizedBox(height: 20),
            Text(
              msg ?? 'No Data Found!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                // foregroundColor: scheme.onPrimary,
                // backgroundColor: scheme.primary,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                Navigator.maybePop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
