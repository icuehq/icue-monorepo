import 'package:flutter/material.dart';

class NoDataWidget extends StatelessWidget {
  const NoDataWidget({super.key, this.msg, this.image, this.size});

  final String? msg;
  final String? image;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Image.asset(
                image ?? 'assets/no_data.webp',
                width: size ?? 300,
                errorBuilder: (_, _, _) => Icon(
                  Icons.inbox_outlined,
                  size: size ?? 120,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              msg ?? 'No Data Found!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
